# Agent Task Completion Evaluation
Evaluation mechanism to validate Agent task completion (e2e)
- Refer [LCORE-Eval repo](https://github.com/lightspeed-core/lightspeed-evaluation/tree/main/lsc_agent_eval) for setup.
- Supports `sub-string`, `judge-llm` and `script` based evaluation.
- Supports multi-turn evaluation.

## Prerequisites
- **Python**: Version 3.11 to 3.12
- **Assisted Chat API**: Must be running (`make build-images run`)
- Install lightspeed-core **agent e2e eval**
```bash
pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval
```
- `GEMINI_API_KEY` env var is set

## Running tests

`make test-eval` runs the tests.
