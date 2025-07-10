# Agent Task Completion Evaluation
Evaluation mechanism to validate Agent task completion (e2e)
- Supports `script` (similar to [k8s-bench](https://github.com/GoogleCloudPlatform/kubectl-ai/tree/main/k8s-bench)), `sub-string` and `judge-llm` based evaluation.
- Refer [eval data setup](https://github.com/asamal4/lightspeed-evaluation/blob/agent-goal-eval/agent_eval/data/agent_goal_eval.yaml)
- Currently it is single-turn evaluation process.

## Prerequisites
- **Python**: Version 3.11.1 to 3.12.9
- **Assisted Chat API**: Must be running
- Install lightspeed-core **agent e2e eval**
```bash
python -m pip install git+https://github.com/asamal4/lightspeed-evaluation.git@agent-goal-eval#subdirectory=agent_eval
```
- Add `OCM Token` to a text file (Ex: ocm_token.txt)
- Create **eval data yaml** file (Ex: eval_data.yaml) [reference](https://github.com/asamal4/lightspeed-evaluation/blob/agent-goal-eval/agent_eval/data/agent_goal_eval.yaml)
- Refer [Eval README](https://github.com/asamal4/lightspeed-evaluation/blob/agent-goal-eval/agent_eval/README.md) for **judge model** setup

## Sample Code
```python
from agent_eval import AgentGoalEval  # TODO: will change the package name

# Create Eval config/args (Alternatively Namespace can be used)
class EvalArgs:
   def __init__(self):
       self.eval_data_yaml = 'eval_data.yaml'
       self.agent_endpoint = 'http://localhost:8090'
       self.agent_provider = 'gemini'
       self.agent_model = 'gemini/gemini-2.5-flash'
       self.judge_provider = None
       self.judge_model = None
       self.agent_auth_token_file = 'ocm_token.txt'  # TODO: will move to env variable.
       self.result_dir = 'results/'
args = EvalArgs()

# Run evaluation
evaluator = AgentGoalEval(args)
evaluator.get_eval_result()
```

### Result
- Test summary is stored in **agent_goal_eval_results.csv**
- Console output
```text
=======================
EVALUATION SUMMARY
=======================
Total Evaluations: 4
Passed: 2
Failed: 1
Errored: 1
Success Rate: 50.0%
=======================
```
