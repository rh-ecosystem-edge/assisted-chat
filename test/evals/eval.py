"""Agent goal evaluation."""

import argparse
import logging
import sys

from lsc_agent_eval import AgentGoalEval

# Configure logging to show all messages from agent_eval library
logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

# Enable specific loggers we want to see
logging.getLogger("lsc_agent_eval").setLevel(logging.INFO)


# Create proper Namespace object for AgentGoalEval
args = argparse.Namespace()
args.eval_data_yaml = "eval_data.yaml"
args.agent_endpoint = "http://localhost:8090"
args.agent_provider = "gemini"
args.agent_model = "gemini/gemini-2.5-flash"
# Set up judge model for LLM evaluation
args.judge_provider = "gemini"
args.judge_model = "gemini-2.5-flash"
args.agent_auth_token_file = "ocm_token.txt"
args.result_dir = "eval_output"

evaluator = AgentGoalEval(args)
# Run Evaluation
evaluator.run_evaluation()
# Get result summary
result_summary = evaluator.get_result_summary()

failed_evals_count = result_summary["FAIL"] + result_summary["ERROR"]
if failed_evals_count:
    print(f"❌ {failed_evals_count} evaluation(s) failed!")
    sys.exit(1)

print("🎉 All evaluations passed!")
sys.exit(0)
