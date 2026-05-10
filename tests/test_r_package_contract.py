import shutil
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


def test_package_metadata_and_core_files_are_present():
    description = (ROOT / "DESCRIPTION").read_text(encoding="utf-8")
    namespace = (ROOT / "NAMESPACE").read_text(encoding="utf-8")

    assert "Package: cbamm" in description
    assert "Collaborative Bayesian Adaptive Meta-Analysis" in description
    assert "export(" in namespace
    for path in [
        "R/cbamm-main.R",
        "R/cbamm-package.R",
        "data/example_meta.rda",
        "data/bcg_data.rda",
    ]:
        assert (ROOT / path).exists()


def test_example_data_generator_uses_repo_relative_output():
    text = (ROOT / "data-raw" / "create_example_data.R").read_text(encoding="utf-8")
    assert "C:" + "/Users/" not in text
    assert "C:" + "\\Users\\" not in text
    assert 'file.path(out_dir, "example_meta.rda")' in text


def test_r_testthat_suite_passes_when_rscript_is_available():
    rscript = shutil.which("Rscript")
    if rscript is None:
        pytest.skip("Rscript is not installed in this environment")
    subprocess.run([rscript, "tests/testthat.R"], cwd=ROOT, check=True)
