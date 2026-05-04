#!/usr/bin/env python3
"""Valida XML de EnvioBOLETA contra ``schema_envio_bol/EnvioBOLETA_v11.xsd``.

El XSD del SII incluye restricciones derivadas de ``SiiDte:PctType`` con
``minInclusive`` 0.00, incompatibles con el tipo base (minimo efectivo 0.01).
Antes de compilar el esquema se corrige ese facet en memoria (misma idea que en
pagosbf ``xml_builder.validate_dte_xml`` para boleta).

Requiere ``lxml`` (ej. ``frappe-bench/env/bin/python``).

Uso::

  /path/frappe-bench/env/bin/python sii/validate_envio_boleta_xsd.py \\
    sii/out_be_certificacion/envio_firmado.xml

  /path/frappe-bench/env/bin/python sii/validate_envio_boleta_xsd.py \\
    --schema-dir sii/schema_envio_bol \\
    sii/out_be_certificacion/envio_borrador.xml \\
    sii/out_be_certificacion/envio_firmado.xml
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


XS_NS = "http://www.w3.org/2001/XMLSchema"
XS = {"xs": XS_NS}


def _patch_pct_min_inclusive(tree):
	"""Corrige facets invalidos sobre PctType para que XMLSchema compile."""
	for el in tree.xpath("//xs:restriction[@base='SiiDte:PctType']/xs:minInclusive[@value='0.00']", namespaces=XS):
		el.set("value", "0.01")


def load_envio_boleta_schema(schema_dir: Path):
	try:
		from lxml import etree
	except ImportError as e:
		print(
			"ERROR: falta lxml. Use el Python del bench, ej:\n"
			"  frappe-bench/env/bin/python sii/validate_envio_boleta_xsd.py ...",
			file=sys.stderr,
		)
		raise SystemExit(2) from e

	main_xsd = schema_dir.resolve() / "EnvioBOLETA_v11.xsd"
	if not main_xsd.is_file():
		print(f"ERROR: no existe {main_xsd}", file=sys.stderr)
		raise SystemExit(1)

	tree = etree.parse(str(main_xsd))
	_patch_pct_min_inclusive(tree)
	try:
		return etree.XMLSchema(tree)
	except etree.XMLSchemaParseError as e:
		print(f"ERROR compilando XSD: {e}", file=sys.stderr)
		raise SystemExit(1) from e


def validate_one(schema, xml_path: Path, *, verbose: bool) -> bool:
	from lxml import etree

	p = xml_path.resolve()
	if not p.is_file():
		print(f"ERROR: no existe {p}", file=sys.stderr)
		return False
	doc = etree.parse(str(p))
	ok = schema.validate(doc)
	if ok:
		if verbose:
			print(f"OK {p}")
		return True
	print(f"INVALID {p}", file=sys.stderr)
	for err in schema.error_log:
		print(f"  line {err.line}: {err.message}", file=sys.stderr)
	return False


def main() -> None:
	here = Path(__file__).resolve().parent
	parser = argparse.ArgumentParser(description="Valida EnvioBOLETA contra XSD oficial (parche PctType).")
	parser.add_argument(
		"--schema-dir",
		type=Path,
		default=here / "schema_envio_bol",
		help="Directorio con EnvioBOLETA_v11.xsd y xmldsignature_v10.xsd",
	)
	parser.add_argument("-v", "--verbose", action="store_true", help="Imprime OK por archivo")
	parser.add_argument("xml_files", nargs="+", type=Path, help="XML a validar (ej. envio_firmado.xml)")
	args = parser.parse_args()

	schema = load_envio_boleta_schema(args.schema_dir)
	all_ok = True
	for xf in args.xml_files:
		if not validate_one(schema, xf, verbose=args.verbose):
			all_ok = False
	if not all_ok:
		raise SystemExit(1)


if __name__ == "__main__":
	main()
