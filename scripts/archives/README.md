# Data Archive Tools

This directory contains a set of scripts to help with processing the data collected from lightspeed
(transcripts and feedback requests).

To sync that latest archive data from s3, run:

`$ ./download-and-extract prod`

(replacing `prod` with `stage` if you want integration/stage data). This requires your local
Kerberos to be setup for an internal RedHat user.

This puts all of the extracted archives in the local `extracted` directory. Feedback is directly
viewable in there. The transcripts are also there but each query/response pair is a separate file so
it isn't very easy to view.

If you then want to aggregate all of the transcripts and correlate them to any feedback for a single
conversation, run:

`$ ./summarize-transcripts`

and everything in the `extracted` dir will be summarized and put into the `summaries` dir. The
file names are the conversation ids. Any feedback associated with that conversation will be put
inline with the conversation chat history, along with tool calls to the MCP server.

## Env Requirements

- https://github.com/app-sre/rh-aws-saml-login
- Python 3.12+
- AWS cli tool
- Local kerberos setup for RedHat internal user
