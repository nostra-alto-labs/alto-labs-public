import requests
import json
import sys
import time
import subprocess

# Setting up initial variables
GIT_CLONE_URL_FMT = (
    "https://nostra-labs-readonly:{access_token}@github.com/nostra-alto-labs/alto-labs"
)
# client_id is taken from the GitHub OAuth app
client_id = "fa5db308656cf59268bf"
headers = {"Content-type": "application/json", "Accept": "application/json"}


# Function to handle errors from GitHub
def error_handling(reply):
    error = reply["error"]
    error_description = reply["error_description"]

    if error == "authorization_pending":
        msg = f"""ERROR: {error_description}
Please authorize user code on GitHub...
"""
        print(msg)

    elif error == "slow_down":
        interval = reply["interval"]
        msg = f"""ERROR: {error_description}
Please wait at least {interval} seconds before you will press Enter again...
    """
        print(msg)

    else:
        # Returning system error to the shell script if user_code expired.
        # That will Restart this script again.
        print("ERROR: Authorization token expired.\n\n")
        sys.exit(2)


# Setting up variables for HTTPS POST (1st authentication stage)
url = "https://github.com/login/device/code"
data = {"client_id": client_id, "scope": "repo"}

# Sending request towards GitHub to start device authentication flow
r = requests.post(url, data=json.dumps(data), headers=headers)
reply = dict(r.json())

# Extracting data from the JSON
user_code = reply["user_code"]
device_code = reply["device_code"]
verification_uri = reply["verification_uri"]
expires_in = reply["expires_in"]

# Storing time when this script has been executed
time_start = time.time()

# Setting up variables for HTTPS POST (3rd authentication stage)
url = "https://github.com/login/oauth/access_token"
data = {
    "client_id": client_id,
    "device_code": device_code,
    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
}

# While loop until access_token is received and repository is cloned
while True:

    # Calculating time which left until user_code will expire (15 minutes by default)
    time_now = time.time()
    time_delta = round(time_now - time_start)
    mins, secs = divmod(expires_in - time_delta, 60)
    time_left = "{:02d} min {:02d} sec.".format(mins, secs)

    # Printing user_code which should be provided on GitHub to authorize request
    print(
        f"""Please authorize user code {user_code} at {verification_uri} or provide it to the Alto Team.
This code is valid for the next {time_left}.
"""
    )

    input("Press Enter to continue...")
    print("\n")

    # Sending request towards GitHub to get access_token
    r = requests.post(url, data=json.dumps(data), headers=headers)
    if not r.ok:
        print(
            f"""ERROR: No reply received from GitHub. Error code: {r}


"""
        )
        sys.exit(2)

    reply = dict(r.json())

    # Error handling
    if "error" in reply:
        error_handling(reply)
        continue

    # Repository cloning
    access_token = reply["access_token"]
    command = ["git", "clone", GIT_CLONE_URL_FMT.format(access_token=access_token)]
    subprocess.call(command)
    sys.exit()
