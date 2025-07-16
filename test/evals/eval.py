import sys
from agent_eval import AgentGoalEval

def print_test_result(result, config):
    """Print test result in human readable format."""
    if result.result == "PASS":
        print(f"✅ {result.eval_id}: PASSED")
    else:
        print(f"❌ {result.eval_id}: {result.result}")
        print(f"   Evaluation Type: {result.eval_type}")
        print(f"   Query: {result.query}")
        print(f"   Response: {result.response}")

        # Show expected values based on eval type
        if config.eval_type == "sub-string" and config.expected_key_words:
            print(f"   Expected Keywords: {config.expected_key_words}")
        elif config.eval_type == "judge-llm" and config.expected_response:
            print(f"   Expected Response: {config.expected_response}")
        elif config.eval_type == "script" and config.eval_verify_script:
            print(f"   Verification Script: {config.eval_verify_script}")

        if result.error:
            print(f"   Error: {result.error}")
        print()

class EvalArgs:
   def __init__(self):
       self.eval_data_yaml = 'eval_data.yaml'
       self.agent_endpoint = 'http://localhost:8090'
       self.agent_provider = 'gemini'
       self.agent_model = 'gemini/gemini-2.5-flash'
       self.judge_provider = None
       self.judge_model = None
       self.agent_auth_token_file = 'ocm_token.txt'
       self.result_dir = 'results'

args = EvalArgs()

evaluator = AgentGoalEval(args)
configs = evaluator.config_manager.get_eval_data()

print(f"Running {len(configs)} evaluation(s)...")
print("=" * 50)

passed = 0
failed = 0

for i, config in enumerate(configs, 1):
    print(f"[{i}/{len(configs)}] Running: {config.eval_id}")

    result = evaluator.evaluation_runner.run_evaluation(
        config, args.agent_provider, args.agent_model
    )

    # Count results as we go
    if result.result == "PASS":
        passed += 1
    else:
        failed += 1

    # Print result immediately
    print_test_result(result, config)

# Print final summary
print("=" * 50)
total = len(configs)

print(f"FINAL RESULTS: {passed}/{total} passed")

if failed > 0:
    print(f"❌ {failed} evaluation(s) failed!")
    sys.exit(1)
else:
    print("🎉 All evaluations passed!")
    sys.exit(0)
