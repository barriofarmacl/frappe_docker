#!/usr/bin/env python3
"""
Parche para Frappe setup_db.py en entornos MariaDB Cloud (SkySQL).

Cuando MARIADB_CLOUD_USE_ROOT_FOR_SITE=1, el usuario administrador no tiene
permisos GRANT sobre bases creadas (error 1044). Este script modifica
setup_database() para solo crear la base y usar el mismo usuario (root) para
el sitio, sin CREATE USER ni GRANT.

Ademas parchea installer.py (site_config con db_user), setup_db.py (restore_database user) y
frappe/__init__.py (connect() usa conf.db_user en v15; en v15 connect usa user=conf.db_name).

Uso: ejecutar antes de 'bench new-site' en el contenedor create-site.
Variables de entorno: MARIADB_CLOUD_USE_ROOT_FOR_SITE, DB_ROOT_USERNAME, DB_ROOT_PASSWORD.
"""
import os
import sys

SETUP_DB_PATH = "/home/frappe/frappe-bench/apps/frappe/frappe/database/mariadb/setup_db.py"
INSTALLER_PATH = "/home/frappe/frappe-bench/apps/frappe/frappe/installer.py"
FRAPPE_INIT_PATH = "/home/frappe/frappe-bench/apps/frappe/frappe/__init__.py"
# frappe/__init__.py connect(): v15 usa user=local.conf.db_name; debe usar db_user si existe
FRAPPE_CONNECT_ANCHORS = [
    ("user=local.conf.db_name or db_name,", 'user=local.conf.get("db_user", local.conf.db_name or db_name),'),
]
# installer.py: inyectar site_config con root antes de make_conf (Frappe usa tab)
INSTALLER_ANCHORS = [
    (
        "\n\tmake_conf(\n\t\tdb_name,",
        """
\tif os.environ.get("MARIADB_CLOUD_USE_ROOT_FOR_SITE"):
\t\tsite_config = site_config or {}
\t\tsite_config = dict(site_config)
\t\tsite_config["db_name"] = db_name
\t\tsite_config["db_user"] = os.environ.get("DB_ROOT_USERNAME", root_login)
\t\tsite_config["db_password"] = os.environ.get("DB_ROOT_PASSWORD", root_password)

\tmake_conf(
\t\tdb_name,""",
    ),
    (
        "\n make_conf(\n db_name,",
        """
 if os.environ.get("MARIADB_CLOUD_USE_ROOT_FOR_SITE"):
  site_config = site_config or {}
  site_config = dict(site_config)
  site_config["db_name"] = db_name
  site_config["db_user"] = os.environ.get("DB_ROOT_USERNAME", root_login)
  site_config["db_password"] = os.environ.get("DB_ROOT_PASSWORD", root_password)

 make_conf(
 db_name,""",
    ),
    (
        "\n    make_conf(\n        db_name,",
        """
    if os.environ.get("MARIADB_CLOUD_USE_ROOT_FOR_SITE"):
        site_config = site_config or {}
        site_config = dict(site_config)
        site_config["db_name"] = db_name
        site_config["db_user"] = os.environ.get("DB_ROOT_USERNAME", root_login)
        site_config["db_password"] = os.environ.get("DB_ROOT_PASSWORD", root_password)

    make_conf(
        db_name,""",
    ),
]
# setup_db.py import_db_from_sql: restore_database(..., user, password) debe usar db_user, no db_name
RESTORE_ANCHORS = [
    ("source_sql, db_name, frappe.conf.db_password", "source_sql, frappe.conf.get(\"db_user\", db_name), frappe.conf.db_password"),
]
# Indent: Frappe puede usar tab o 4 espacios segun version/build
ANCHORS_AND_BLOCKS = [
    (
        "\tif force or (db_name not in dbman.get_database_list()):",
        """\tif os.environ.get("MARIADB_CLOUD_USE_ROOT_FOR_SITE"):
\t\tfrappe.local.conf["db_user"] = os.environ.get("DB_ROOT_USERNAME", frappe.flags.root_login)
\t\tfrappe.local.conf["db_password"] = os.environ.get("DB_ROOT_PASSWORD", frappe.flags.root_password)
\t\tif force or (db_name not in dbman.get_database_list()):
\t\t\tdbman.create_database(db_name)
\t\telse:
\t\t\traise Exception(f"Database {db_name} already exists")
\t\tfrappe.local.db = None
\t\troot_conn.close()
\t\treturn

""",
    ),
    (
        "    if force or (db_name not in dbman.get_database_list()):",
        """    if os.environ.get("MARIADB_CLOUD_USE_ROOT_FOR_SITE"):
        frappe.local.conf["db_user"] = os.environ.get("DB_ROOT_USERNAME", frappe.flags.root_login)
        frappe.local.conf["db_password"] = os.environ.get("DB_ROOT_PASSWORD", frappe.flags.root_password)
        if force or (db_name not in dbman.get_database_list()):
            dbman.create_database(db_name)
        else:
            raise Exception(f"Database {db_name} already exists")
        frappe.local.db = None
        root_conn.close()
        return

""",
    ),
]


def _patch_frappe_connect():
    """Hacer que connect() use conf.db_user si existe (v15 usa solo db_name como user)."""
    if not os.path.isfile(FRAPPE_INIT_PATH):
        return True
    with open(FRAPPE_INIT_PATH, "r") as f:
        content = f.read()
    if 'local.conf.get("db_user"' in content:
        return True
    for old, new in FRAPPE_CONNECT_ANCHORS:
        if old in content:
            with open(FRAPPE_INIT_PATH, "w") as f:
                f.write(content.replace(old, new, 1))
            return True
    print("patch_mariadb_cloud_setup_db: ancla connect no encontrada en frappe/__init__.py", file=sys.stderr)
    return False


def _patch_installer():
    """Fuerza site_config con db_user/db_password root antes de make_conf."""
    if not os.path.isfile(INSTALLER_PATH):
        return True
    with open(INSTALLER_PATH, "r") as f:
        content = f.read()
    if "MARIADB_CLOUD_USE_ROOT_FOR_SITE" in content:
        return True
    for anchor, block in INSTALLER_ANCHORS:
        if anchor in content:
            new_content = content.replace(anchor, block, 1)
            with open(INSTALLER_PATH, "w") as f:
                f.write(new_content)
            return True
    print("patch_mariadb_cloud_setup_db: ancla no encontrada en installer.py", file=sys.stderr)
    return False


def _patch_restore_user(content):
    """Hacer que import_db_from_sql pase db_user a restore_database en lugar de db_name."""
    if 'frappe.conf.get("db_user", db_name)' in content or "frappe.conf.get('db_user', db_name)" in content:
        return content, True
    for old, new in RESTORE_ANCHORS:
        if old in content:
            return content.replace(old, new, 1), True
    return content, False


def main():
    if not os.environ.get("MARIADB_CLOUD_USE_ROOT_FOR_SITE"):
        return 0
    if not os.path.isfile(SETUP_DB_PATH):
        print("patch_mariadb_cloud_setup_db: setup_db.py no encontrado, omitiendo parche", file=sys.stderr)
        return 0
    if not _patch_installer():
        return 1
    if not _patch_frappe_connect():
        return 1
    with open(SETUP_DB_PATH, "r") as f:
        content = f.read()
    content, restored = _patch_restore_user(content)
    if restored:
        with open(SETUP_DB_PATH, "w") as f:
            f.write(content)
    if "MARIADB_CLOUD_USE_ROOT_FOR_SITE" in content:
        return 0
    for anchor, block in ANCHORS_AND_BLOCKS:
        if anchor in content:
            new_content = content.replace(anchor, block + anchor, 1)
            with open(SETUP_DB_PATH, "w") as f:
                f.write(new_content)
            return 0
    print("patch_mariadb_cloud_setup_db: ancla no encontrada en setup_db.py (indent tab o 4 espacios)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
