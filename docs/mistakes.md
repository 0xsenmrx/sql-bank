# Mistakes Log

## Test Isolation Failed Due to Hardcoded Source Path
**Date:** Oct 31, 2026

**What I assumed:** 
I assumed that passing `ENV_FILE="$TEMP_DIR/.env.test"` to my scripts would be enough to redirect them to the test database (`bank_test`). I thought the scripts would automatically respect this variable.

**What was true:** 
My `_common.sh` script used `source .env` literally, completely ignoring the `ENV_FILE` variable I had exported. Because of this, when `test.sh` ran `reset.sh`, `reset.sh` read the real `.env` file and dropped/recreated the real `bank` database instead of `bank_test`. The test then failed with `database "bank_test" does not exist`.

**The cause:** 
I defined the `ENV_FILE` variable with a default (`ENV_FILE="${ENV_FILE:-.env}"`), but I never actually *used* the variable in the `source` command. 

**The fix:** 
1. Changed `_common.sh` to `source "$ENV_FILE"` so it respects the variable.
2. Added a **Safety Assertion** at the top of `test.sh` that checks if `POSTGRES_DB` is `bank_test` before running any destructive commands. If it isn't, it exits immediately. 
3. Moved the `source _common.sh` call in `test.sh` to happen *after* the test environment variables were exported.

**Lesson learned:** 
Never trust a script that runs `DROP DATABASE` without a hardcoded safety check preventing it from targeting the wrong database. Environment variables need to be verified, not just assumed.
