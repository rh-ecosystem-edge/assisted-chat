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
pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval
```
- `GEMINI_API_KEY` env var is set

## Running tests

`make test-eval` runs the tests.

Example output:

```
Refreshing OCM token...
Running agent evaluation tests...
2025-07-21 09:18:39,195 - lsc_agent_eval.core.utils.judge - INFO - Setting up LiteLLM for gemini/gemini-2.5-flash
2025-07-21 09:18:39,195 - lsc_agent_eval.core.utils.judge - WARNING - Using generic provider format for gemini
Running 4 evaluation(s)...
==================================================
[1/4] Running: basic_introduction
2025-07-21 09:18:40,039 - lsc_agent_eval.core.utils.api_client - INFO - Agent response >
Hello! I'm an AI assistant for the Assisted Installer. I can help you create OpenShift clusters, list available versions, get cluster information, and more. What would you like to do today?
✅ basic_introduction: PASSED
[2/4] Running: basic_cluster_request
2025-07-21 09:18:46,006 - lsc_agent_eval.core.utils.api_client - INFO - Agent response >
I can help with that. What would you like to name your cluster? What OpenShift version do you want to install? What is the base domain for your cluster? Will this be a single-node cluster (True/False)?
✅ basic_cluster_request: PASSED
[3/4] Running: list_versions
2025-07-21 09:18:52,458 - lsc_agent_eval.core.utils.api_client - INFO - Agent response >
Here are the available OpenShift versions and their support levels:

**Production:**
* 4.19.3 (default)
* 4.19.3-multi
* 4.18.19
* 4.18.19-multi

**Maintenance:**
* 4.17.35
* 4.17.35-multi
* 4.16.43
* 4.16.43-multi
* 4.15.54
* 4.15.54-multi

**Extended Support:**
* 4.14.51
* 4.14.51-multi
* 4.12.71

**Beta:**
* 4.20.0-ec.4
* 4.20.0-ec.4-multi

**End-of-Life:**
* 4.11.59
* 4.10.67
* 4.9.17
✅ list_versions: PASSED
[4/4] Running: available_operators
2025-07-21 09:18:58,051 - lsc_agent_eval.core.utils.api_client - INFO - Agent response >
There are two operator bundles available:

*   **Virtualization**: Run virtual machines alongside containers on one platform. This bundle includes operators like `mtv`, `node-healthcheck`, `nmstate`, `node-maintenance`, `kube-descheduler`, `cnv`, `self-node-remediation`, and `fence-agents-remediation`.
*   **OpenShift AI**: Train, serve, monitor and manage AI/ML models and applications using GPUs. This bundle includes operators like `openshift-ai`, `amd-gpu`, `node-feature-discovery`, `pipelines`, `servicemesh`, `authorino`, `kmm`, `odf`, `serverless`, and `nvidia-gpu`.
✅ available_operators: PASSED
==================================================
FINAL RESULTS: 4/4 passed
🎉 All evaluations passed!
```
