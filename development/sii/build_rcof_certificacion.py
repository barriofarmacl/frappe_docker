#!/usr/bin/env python3
"""Genera y firma el XML de Consumo de Folios (RCOF) para boletas electrónicas.

Lee un sobre ``EnvioBOLETA`` firmado (p. ej. ``envio_firmado.xml`` del set certificación),
agrega totales por tipo DTE (39/41), arma ``ConsumoFolios`` según ``ConsumoFolio_v10.xsd``
y firma con el mismo PFX que el envío de boletas.

Salida:
  ``rcof_firmado.xml`` (ISO-8859-1, XMLDSig RSA-SHA1).

Requiere ``PYTHONPATH`` apuntando al directorio de la app ``pagosbf`` y el venv del bench
(con ``cryptography``, ``lxml``, ``signxml``). Si ejecutas ``python3`` global o un **shim**
(pyenv) que comparte binario con el venv pero **no** activa ``sys.prefix`` del bench, el
script detecta deps faltantes y se **re-lanza** con ``frappe-bench/env/bin/python`` (layout
``development/sii/`` -> ``development/frappe-bench/``).

Ejemplo::

  export PYTHONPATH=/workspace/development/frappe-bench/apps/pagosbf
  ../frappe-bench/env/bin/python sii/build_rcof_certificacion.py \\
    --envio-xml sii/out_be_certificacion/envio_firmado.xml \\
    --out sii/out_be_certificacion/rcof_firmado.xml \\
    --rut-emisor 76957985-0 \\
    --rut-envia 15437220-2 \\
    --fch-resol 2026-04-30 \\
    --nro-resol 0 \\
    --fch-inicio 2026-05-03 \\
    --fch-final 2026-05-03 \\
    --sec-envio 1 \\
    --pfx sii/15437220-2.pfx \\
    --pfx-password \"\$CERT_PFX_PASSWORD\"

La subida al portal SII de certificación suele ser manual (Consumo de folios); el CGI puede
diferir del ``DTEUpload`` de boletas — ver manual técnico vigente.
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path


def _pagosbf_runtime_deps_ok() -> bool:
	"""Modulos que importa la cadena ``xml_signer`` / ``rcof_builder``."""
	try:
		import cryptography  # noqa: F401
		import lxml.etree  # noqa: F401
		import signxml  # noqa: F401
	except ModuleNotFoundError:
		return False
	return True


def _running_inside_bench_venv(bench_env: Path) -> bool:
	"""True si este proceso usa ``sys.prefix`` del virtualenv del bench (no basta comparar binarios: pyenv/shim puede ser el mismo file sin activar el venv)."""
	try:
		return Path(sys.prefix).resolve() == bench_env.resolve()
	except OSError:
		return False


def _reexec_with_bench_venv_if_needed() -> None:
	"""Si faltan deps, re-lanzar con ``frappe-bench/env/bin/python`` para activar el venv correcto."""
	here = Path(__file__).resolve().parent
	dev = here.parent
	bench_env = dev / "frappe-bench" / "env"
	bench_py = bench_env / "bin" / "python"
	script = Path(__file__).resolve()
	if _pagosbf_runtime_deps_ok():
		return
	if bench_py.is_file() and not _running_inside_bench_venv(bench_env):
		os.execv(str(bench_py), [str(bench_py), str(script), *sys.argv[1:]])
	print(
		"ERROR: faltan modulos requeridos (cryptography, lxml, signxml) en el venv del bench.",
		file=sys.stderr,
	)
	print("  Pruebe: cd frappe-bench && ./env/bin/pip install -e apps/pagosbf", file=sys.stderr)
	print("  o: bench setup requirements", file=sys.stderr)
	print("  export PYTHONPATH=<...>/frappe-bench/apps/pagosbf", file=sys.stderr)
	print(f"  {bench_py} {script} ...", file=sys.stderr)
	sys.exit(1)


_reexec_with_bench_venv_if_needed()

from zoneinfo import ZoneInfo

try:
	_CL_TZ = ZoneInfo("America/Santiago")
except Exception:  # noqa: BLE001
	from datetime import timezone

	_CL_TZ = timezone.utc


def _now_santiago_naive() -> datetime:
	return datetime.now(tz=_CL_TZ).replace(tzinfo=None, microsecond=0)


def _pagosbf_root() -> Path:
	here = Path(__file__).resolve().parent
	dev = here.parent
	return dev / "frappe-bench" / "apps" / "pagosbf"


def _ensure_import_path() -> None:
	root = _pagosbf_root()
	if not root.is_dir():
		print(f"ERROR: no existe ruta pagosbf esperada: {root}", file=sys.stderr)
		sys.exit(1)
	p = str(root)
	if p not in sys.path:
		sys.path.insert(0, p)


def main() -> None:
	_ensure_import_path()
	from pagosbf.pagosbf.dte import xml_signer
	from pagosbf.pagosbf.dte.rcof_builder import (
		CaratulaRcof,
		aggregate_resumenes_from_envio_boleta_xml,
		build_consumo_folios_draft_bytes,
		validate_rcof_xml_signed,
	)

	parser = argparse.ArgumentParser(description="RCOF firmado desde EnvioBOLETA XML")
	parser.add_argument("--envio-xml", required=True, type=Path, help="Sobre EnvioBOLETA (firmado)")
	parser.add_argument("--out", required=True, type=Path, help="Salida rcof_firmado.xml")
	parser.add_argument("--rut-emisor", required=True)
	parser.add_argument("--rut-envia", required=True)
	parser.add_argument("--fch-resol", required=True, help="YYYY-MM-DD")
	parser.add_argument("--nro-resol", required=True, type=int)
	parser.add_argument("--fch-inicio", required=True)
	parser.add_argument("--fch-final", required=True)
	parser.add_argument("--sec-envio", required=True, type=int)
	parser.add_argument("--correlativo", type=int, default=None)
	parser.add_argument(
		"--tmst-firma-env",
		default=None,
		help="YYYY-MM-DDTHH:MM:SS (default: ahora America/Santiago)",
	)
	parser.add_argument("--documento-id", default="RCOF_01")
	parser.add_argument("--pfx", required=True, type=Path)
	parser.add_argument("--pfx-password", default="", help="o env CERT_PFX_PASSWORD")
	parser.add_argument("--skip-xsd", action="store_true", help="No validar XSD tras firmar")
	args = parser.parse_args()

	pwd = args.pfx_password or os.environ.get("CERT_PFX_PASSWORD") or ""
	envio_bytes = args.envio_xml.read_bytes()
	resumenes = aggregate_resumenes_from_envio_boleta_xml(envio_bytes)
	if not resumenes:
		print("ERROR: no se pudieron agregar totales desde el envío (¿Totales dentro de Encabezado?)", file=sys.stderr)
		sys.exit(1)

	if args.tmst_firma_env:
		tmst = datetime.fromisoformat(args.tmst_firma_env)
	else:
		tmst = _now_santiago_naive()

	caratula = CaratulaRcof(
		rut_emisor=args.rut_emisor.strip(),
		rut_envia=args.rut_envia.strip(),
		fch_resol=args.fch_resol.strip(),
		nro_resol=int(args.nro_resol),
		fch_inicio=args.fch_inicio.strip(),
		fch_final=args.fch_final.strip(),
		sec_envio=int(args.sec_envio),
		tmst_firma_env=tmst,
		correlativo=args.correlativo,
	)

	draft = build_consumo_folios_draft_bytes(
		caratula,
		resumenes,
		documento_id=args.documento_id.strip(),
	)

	pfx_bytes = args.pfx.read_bytes()
	mat = xml_signer.load_pfx(pfx_bytes, pwd or None)
	signed = xml_signer.sign_consumo_folios(
		draft,
		mat,
		reference_uri=args.documento_id.strip(),
	)

	if not args.skip_xsd:
		validate_rcof_xml_signed(signed)

	args.out.parent.mkdir(parents=True, exist_ok=True)
	args.out.write_bytes(signed)
	print(f"Escrito {args.out} ({len(signed)} bytes)")


if __name__ == "__main__":
	main()
