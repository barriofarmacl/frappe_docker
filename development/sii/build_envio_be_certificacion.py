#!/usr/bin/env python3
"""Arma el EnvioBOLETA del Set de Prueba BE (5 boletas tipo 39) desde CAF AUTORIZACION.

Entradas esperadas:
  - XML AUTORIZACION del SII (CAF + RSASK), ej. ``FoliosSII76957985-2.xml``.
  - Casos CASO-1..5 alineados a ``Set Prueba BE.txt`` (implementado en pagosbf
    ``be_set_prueba_dte_data``).

Salida (``--out-dir``):
  - ``dte_prefirma_{folio}.xml`` — DTE con TED y TmstFirma, sin XMLDSig (validado XSD).
  - Con ``--pfx`` + password: ``dte_firmado_{folio}.xml``, ``envio_borrador.xml``,
    ``envio_firmado.xml``.

	FchEmis / TED / TmstFirma usan la fecha del instante de timbrado (``fe = ts.date()``).
	Sin ``--tmst-firma``, ``ts`` es la hora actual en America/Santiago (evita DTE-1-650
	al subir el mismo dia). Resolucion caratula sigue siendo ``--fch-resol`` / ``--nro-resol``.

Uso::
  export PYTHONPATH=/ruta/apps/pagosbf
  python3 sii/build_envio_be_certificacion.py \\
    --caf sii/FoliosSII76957985-2.xml \\
    --out-dir sii/out_be_certificacion \\
    --rut-envia 15437220-2 \\
    --pfx sii/15437220-2.pfx \\
    --pfx-password \"$CERT_PFX_PASSWORD\"
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

try:
	_CL_TZ = ZoneInfo("America/Santiago")
except Exception:  # noqa: BLE001
	from datetime import timezone

	_CL_TZ = timezone.utc


def _now_santiago_naive() -> datetime:
	"""Instante local Chile sin tz-aware (mismo criterio que emision._now_santiago)."""
	return datetime.now(tz=_CL_TZ).replace(tzinfo=None, microsecond=0)

# Defaults alineados a ficha SII del contribuyente (domicilio, sucursal, actividad 477201).
# GiroEmisor XSD maxLength 80 (el texto completo del SII supera 80; se usa forma abreviada;
#   override con --giro si el certificador indica otra redaccion).
# DirOrigen maxLength 70.
_DEFAULT_GIRO_EMISOR = (
	"VENTA AL POR MENOR PROD. FARMACEUTICOS Y MEDICINALES EN COM. ESPECIALIZADOS"
)
_DEFAULT_DIR_ORIGEN = "ROJAS MAGALLANES #94 DEPTO. #B"
_DEFAULT_CMNA_ORIGEN = "LA FLORIDA"
_DEFAULT_CIUDAD_ORIGEN = "LA FLORIDA"
_DEFAULT_CDG_SII_SUCUR = "82798222"


def _pagosbf_root() -> Path:
	here = Path(__file__).resolve().parent
	# workspace/development/sii -> workspace/development/frappe-bench/apps/pagosbf
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


def _emisor_from_args(args: argparse.Namespace, caf_data):
	from pagosbf.pagosbf.dte.types import Emisor

	co = getattr(args, "ciudad_origen", None)
	ciudad = str(co).strip() if co else None
	if ciudad == "":
		ciudad = None

	suc = getattr(args, "cdg_sii_sucur", None)
	cdg = None
	if suc is not None and str(suc).strip():
		cdg = int(str(suc).strip().lstrip("#"))

	return Emisor(
		rut=caf_data.rut_emisor,
		razon_social=caf_data.razon_social_emisor,
		giro=args.giro.strip(),
		direccion_origen=args.dir_origen.strip(),
		comuna_origen=args.cmna_origen.strip(),
		resolucion_numero=args.nro_resol,
		resolucion_fecha=args.fch_resol,
		ciudad_origen=ciudad,
		cdg_sii_sucur=cdg,
	)


def main() -> None:
	parser = argparse.ArgumentParser(description="Construye EnvioBOLETA set prueba BE desde CAF.")
	parser.add_argument(
		"--caf",
		type=Path,
		default=Path(__file__).resolve().parent / "FoliosSII76957985-2.xml",
		help="XML AUTORIZACION (CAF + RSASK)",
	)
	parser.add_argument(
		"--out-dir",
		type=Path,
		default=Path(__file__).resolve().parent / "out_be_certificacion",
		help="Directorio de salida",
	)
	parser.add_argument(
		"--rut-envia",
		default=os.environ.get("SII_RUT_ENVIA", ""),
		help="Rut que envia (caratula); debe coincidir con certificado PFX",
	)
	parser.add_argument("--pfx", type=Path, help="Ruta PKCS#12 del certificado digital")
	parser.add_argument(
		"--pfx-password",
		default=os.environ.get("CERT_PFX_PASSWORD", ""),
		help="Password PFX (o env CERT_PFX_PASSWORD)",
	)
	parser.add_argument(
		"--giro",
		default=_DEFAULT_GIRO_EMISOR,
		help="Giro emisor en DTE (max 80 caracteres XSD; actividad asociada al negocio)",
	)
	parser.add_argument(
		"--dir-origen",
		default=_DEFAULT_DIR_ORIGEN,
		help="Direccion origen emisor (max 70 caracteres XSD)",
	)
	parser.add_argument(
		"--cmna-origen",
		default=_DEFAULT_CMNA_ORIGEN,
		help="Comuna origen (domicilio SII)",
	)
	parser.add_argument(
		"--ciudad-origen",
		default=_DEFAULT_CIUDAD_ORIGEN,
		help="Ciudad origen (opcional en XSD; vacio para omitir si pagosbf lo soporta)",
	)
	parser.add_argument(
		"--cdg-sii-sucur",
		default=_DEFAULT_CDG_SII_SUCUR,
		help="Codigo sucursal SII (CdgSIISucur); vacio para omitir",
	)
	parser.add_argument(
		"--fch-resol",
		type=date.fromisoformat,
		default=date(2026, 4, 30),
		help="Fecha resolucion caratula (AAAA-MM-DD)",
	)
	parser.add_argument("--nro-resol", type=int, default=0, help="Nro resolucion (0 certif.)")
	parser.add_argument(
		"--tmst-firma",
		type=_parse_dt,
		default=None,
		help="Instante TED/TmstFirma y firma DTE (AAAA-MM-DDTHH:MM:SS). "
		"Por defecto: hora actual en America/Santiago (alinea FchEmis y timbre al envio; evita DTE-1-650).",
	)
	parser.add_argument(
		"--set-dte-id", default="SetDte1", help="ID del SetDTE (firma del sobre)"
	)
	parser.add_argument(
		"--use-test-pfx",
		action="store_true",
		help="PFX efimero para probar firma XMLDSig local (no valido en portal SII).",
	)
	args = parser.parse_args()

	# Normalizar omission explicita (--ciudad-origen '' / --cdg-sii-sucur '')
	for attr in ("ciudad_origen", "cdg_sii_sucur"):
		val = getattr(args, attr, None)
		if isinstance(val, str) and not val.strip():
			setattr(args, attr, None)

	if len(args.giro.strip()) > 80:
		print("ERROR: --giro supera 80 caracteres (limite GiroEmisor en XSD boleta).", file=sys.stderr)
		sys.exit(1)
	if len(args.dir_origen.strip()) > 70:
		print("ERROR: --dir-origen supera 70 caracteres (limite DirOrigen en XSD boleta).", file=sys.stderr)
		sys.exit(1)

	_ensure_import_path()

	from pagosbf.pagosbf.dte.be_set_prueba import be_set_prueba_dte_data
	from pagosbf.pagosbf.dte.caf_parser import parse_autorizacion_bytes, CAFParserError
	from pagosbf.pagosbf.dte.constants import TIPO_DTE_BOLETA_AFECTA
	from pagosbf.pagosbf.dte.envio_builder import (
		RUT_SII_CARATULA,
		CaratulaEmision,
		build_envio_boleta_draft_multi,
	)
	from pagosbf.pagosbf.dte.signature_audit import audit_boleta_xml_bytes
	from pagosbf.pagosbf.dte.ted_generator import build_signed_ted
	from pagosbf.pagosbf.dte.types import Emisor
	from pagosbf.pagosbf.dte import xml_builder, xml_signer

	if not args.caf.is_file():
		print(f"ERROR: no existe CAF: {args.caf}", file=sys.stderr)
		sys.exit(1)

	caf_bytes = args.caf.read_bytes()
	try:
		caf_data = parse_autorizacion_bytes(caf_bytes)
	except CAFParserError as e:
		print(f"ERROR parseando CAF: {e}", file=sys.stderr)
		sys.exit(1)

	r0, r1 = int(caf_data.rango_desde), int(caf_data.rango_hasta)
	n = r1 - r0 + 1
	if n != 5:
		print(
			f"ADVERTENCIA: rango CAF tiene {n} folios ({r0}-{r1}); el set BE requiere 5. "
			"Se usan los primeros 5 si n>=5; si n<5 aborta.",
			file=sys.stderr,
		)
	if n < 5:
		sys.exit(1)

	folios = list(range(r0, r0 + 5))
	if args.tmst_firma is not None:
		ts = args.tmst_firma.replace(microsecond=0)
	else:
		ts = _now_santiago_naive()
	fe = ts.date()

	em = _emisor_from_args(args, caf_data)

	args.out_dir.mkdir(parents=True, exist_ok=True)

	signed_list: list[bytes] = []
	material = None
	if args.use_test_pfx:
		from pagosbf.tests.dte_fixtures import pfx_for_tests

		material = xml_signer.load_pfx(pfx_for_tests("test1234"), "test1234")
	elif args.pfx:
		if not args.pfx.is_file():
			print(f"ERROR: PFX no encontrado: {args.pfx}", file=sys.stderr)
			sys.exit(1)
		pwd = args.pfx_password or ""
		material = xml_signer.load_pfx(args.pfx.read_bytes(), pwd or None)

	if not str(args.rut_envia or "").strip():
		print(
			"AVISO: sin --rut-envia (o SII_RUT_ENVIA); caratula quedara incompleta para SII.",
			file=sys.stderr,
		)

	for caso in range(1, 6):
		folio = folios[caso - 1]
		data = be_set_prueba_dte_data(
			caso,
			emisor=em,
			folio=folio,
			fecha_emision=fe,
			timestamp_firma=ts,
		)
		draft = xml_builder.build_dte(data)
		ted = build_signed_ted(draft.dd_data, caf_data, ts)
		dte_pre = xml_builder.insert_ted(draft, ted, ts)
		xml_builder.validate_dte_xml(dte_pre, version="boleta")
		pre_path = args.out_dir / f"dte_prefirma_{folio}.xml"
		pre_path.write_bytes(dte_pre)
		print(f"OK pre-firma XSD: {pre_path}")

		if material is not None:
			dte_f = xml_signer.sign_dte(dte_pre, material, reference_uri=draft.documento_id)
			out_f = args.out_dir / f"dte_firmado_{folio}.xml"
			out_f.write_bytes(dte_f)
			audit = audit_boleta_xml_bytes(dte_f)
			a = audit[0]
			print(
				f"OK firmado: {out_f} | audit: mod_ok={a.modulus_matches_x509} xmldsig_ok={a.xmldsig_verifies}"
			)
			if not (a.modulus_matches_x509 and a.xmldsig_verifies):
				print(f"  detalle: {a.detail}", file=sys.stderr)
			signed_list.append(dte_f)

	if material is not None and signed_list:
		# Misma marca que los DTE si --tmst-firma fijo; si no, hora de cierre del sobre.
		tmst_env = ts if args.tmst_firma is not None else _now_santiago_naive()
		carat = CaratulaEmision(
			rut_emisor=em.rut,
			rut_envia=args.rut_envia.replace(".", "").replace(" ", "").strip(),
			rut_receptor=RUT_SII_CARATULA,
			fch_resol=args.fch_resol,
			nro_resol=args.nro_resol,
			tmst_firma_env=tmst_env,
			tipo_dte=TIPO_DTE_BOLETA_AFECTA,
			nro_dtes=5,
			set_dte_id=args.set_dte_id,
		)
		borrador = build_envio_boleta_draft_multi(signed_list, carat)
		bpath = args.out_dir / "envio_borrador.xml"
		bpath.write_bytes(borrador)
		print(f"OK borrador sobre: {bpath}")
		sobre = xml_signer.sign_envio_boleta(borrador, material, reference_uri=args.set_dte_id)
		spath = args.out_dir / "envio_firmado.xml"
		spath.write_bytes(sobre)
		print(f"OK sobre firmado: {spath}")
	elif not args.pfx and not args.use_test_pfx:
		print(
			"\nSin --pfx ni --use-test-pfx: solo DTE con TED (prefirma). "
			"Para envio SII: --pfx, --pfx-password, --rut-envia.",
			file=sys.stderr,
		)


def _parse_dt(s: str) -> datetime:
	return datetime.fromisoformat(s)


if __name__ == "__main__":
	main()
