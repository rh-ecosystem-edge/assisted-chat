# Agent Task Completion Evaluation
Evaluation mechanism to validate Agent task completion (e2e)
- Supports `script` (similar to [k8s-bench](https://github.com/GoogleCloudPlatform/kubectl-ai/tree/main/k8s-bench)), `sub-string` and `judge-llm` based evaluation.
- Refer [eval data setup](https://github.com/asamal4/lightspeed-evaluation/blob/agent-goal-eval/agent_eval/data/agent_goal_eval.yaml)
- Currently it is single-turn evaluation process.

## Prerequisites
- **Python**: Version 3.11.1 to 3.12.9
- **Assisted Chat API**: Must be running (`make build-images run`)
- Install lightspeed-core **agent e2e eval**
```bash
python -m pip install git+https://github.com/asamal4/lightspeed-evaluation.git@agent-goal-eval#subdirectory=agent_eval
```

## Running tests

`make test-eval` runs the tests.

Example output:

```
Refreshing OCM token...
Running agent evaluation tests...
Running 4 evaluation(s)...
==================================================
[1/4] Running: basic_introduction
❌ basic_introduction: FAIL
   Evaluation Type: sub-string
   Query: Hi!
   Response: Hello! I'm an AI assistant for the Assisted Installer. I can help you create OpenShift clusters, list available versions, get cluster information, and more. What would you like to do?
   Expected Keywords: ['Assisted Installer Chat']

[2/4] Running: basic_cluster_request
✅ basic_cluster_request: PASSED
[3/4] Running: list_versions
✅ list_versions: PASSED
[4/4] Running: available_operators
✅ available_operators: PASSED
==================================================
FINAL RESULTS: 3/4 passed
❌ 1 evaluation(s) failed!
make: *** [Makefile:75: test-eval] Error 1
```
