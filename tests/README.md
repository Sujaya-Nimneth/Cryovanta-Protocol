# Test Corpus

The historical root-level `test_*.gd` suites remain in place for compatibility. `tests/manifest.txt` is the complete nonrecursive registry.

```bash
bash tools/run_tests.sh
```

The runner imports the project, validates the manifest against every root-level suite, runs each suite once with `--direct-regression`, parses final counters, and writes logs under `build/test-logs/`.

New regression suites are added to the root for the current guardrail scans and registered in the manifest. Historical recursive gates remain runnable directly, but the complete corpus gate does not rely on them.

Headless results use the CPU fallback where Vulkan is unavailable. They are not Android device or GPU performance evidence.
