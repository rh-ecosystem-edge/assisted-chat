"""Agent goal evaluation."""

import argparse
import logging
import sys
import os
import yaml
import tempfile

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
def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Agent goal evaluation")

    parser.add_argument(
        "--eval_data_yaml",
        default="eval_data.yaml",
        help="Path to evaluation data YAML file (default: eval_data.yaml)",
    )

    parser.add_argument(
        "--agent_endpoint",
        default="http://localhost:8090",
        help="Agent endpoint URL (default: http://localhost:8090)",
    )

    parser.add_argument(
        "--endpoint_type",
        choices=["streaming", "query"],
        default="streaming",
        help="Endpoint type to use for agent queries (default: streaming)",
    )

    parser.add_argument(
        "--agent_provider", default="gemini", help="Agent provider (default: gemini)"
    )

    parser.add_argument(
        "--agent_model",
        default="gemini-2.0-flash",
        help="Agent model (default: gemini-2.0-flash)",
    )

    parser.add_argument(
        "--judge_provider",
        default="gemini",
        help="Judge provider for LLM evaluation (default: gemini)",
    )

    parser.add_argument(
        "--judge_model",
        default="gemini-2.5-flash",
        help="Judge model for LLM evaluation (default: gemini-2.0-flash)",
    )

    parser.add_argument(
        "--agent_auth_token_file",
        default="ocm_token.txt",
        help="Path to agent auth token file (default: ocm_token.txt)",
    )

    parser.add_argument(
        "--result_dir",
        default="eval_output",
        help="Directory for evaluation results (default: eval_output)",
    )

    parser.add_argument(
        "--tags",
        nargs="+",
        default=None,
        help=(
            "Filter tests by tags. Optional - if not provided, all tests will be run. "
            "Available tags: "
            "'smoke' - Basic smoke tests that verify core functionality and should run quickly "
            "to catch fundamental issues (e.g., cluster creation requests, version listing, "
            "basic queries). "
            "'troubleshooting' - Tests that verify the assistant's ability to help diagnose and "
            "explain common issues users encounter (e.g., ignition download failures, degraded "
            "cluster states, console access problems). "
            "'non-destructive' - Tests that verify the assistant correctly refuses or handles "
            "destructive operations without actually performing them (e.g., refusing to delete "
            "clusters, declining to create deletion scripts). "
            "Example: --tags smoke troubleshooting"
        ),
    )

    return parser.parse_args()


def filter_by_tags(path, tags):
    """Filter YAML data by tags, return filtered path."""
    if not tags:
        return path
    with open(path) as f:
        data = [g for g in yaml.safe_load(f) if any(t in g.get('tags', []) for t in tags)]
    if not data:
        sys.exit(f"⚠️  No tests found with tags: {tags}")
    print(f"📋 Running {len(data)} test(s) with tags: {tags}")
    tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False)
    yaml.dump(data, tmp, default_flow_style=False, sort_keys=False)
    tmp.close()
    return tmp.name


# Parse command line arguments
args = parse_args()
if os.getenv('UNIQUE_ID') is None:
    print("The environmental varialbe 'UNIQUE_ID' has to be set so the cluster creation and removal can happen properly.")
    sys.exit(1)

args.eval_data_yaml = filter_by_tags(args.eval_data_yaml, args.tags)

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
