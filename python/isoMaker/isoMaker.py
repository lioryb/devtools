from pathlib import Path
import pycdlib

BASE_DIR = Path(__file__).resolve().parent

USER_DATA = BASE_DIR / "user-data"
META_DATA = BASE_DIR / "meta-data"
OUT_ISO = BASE_DIR / "seed.iso"

if not USER_DATA.exists():
    raise FileNotFoundError(f"Missing: {USER_DATA}")

if not META_DATA.exists():
    raise FileNotFoundError(f"Missing: {META_DATA}")

if OUT_ISO.exists():
    OUT_ISO.unlink()

iso = pycdlib.PyCdlib()

iso.new(
    interchange_level=3,
    joliet=True,
    rock_ridge="1.09",
    vol_ident="CIDATA",
    sys_ident="LINUX"
)

iso.add_file(
    str(USER_DATA),
    iso_path="/USERDATA.;1",
    joliet_path="/user-data",
    rr_name="user-data"
)

iso.add_file(
    str(META_DATA),
    iso_path="/METADATA.;1",
    joliet_path="/meta-data",
    rr_name="meta-data"
)

iso.write(str(OUT_ISO))
iso.close()

print(f"Created: {OUT_ISO}")
print("Volume label: CIDATA")
print("Files:")
print("  /user-data")
print("  /meta-data")
