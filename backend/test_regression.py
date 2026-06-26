import requests
import json
import time

URL = "http://localhost:5005/webhooks/rest/webhook"

def send_msg(sender, message, metadata=None):
    payload = {"sender": sender, "message": message}
    if metadata:
        payload["metadata"] = metadata
    response = requests.post(URL, json=payload)
    return response.json()

def run_test_1():
    print("\n--- Test 1: headache -> age -> emergency ---")
    sender = "test_1"
    print("User: headache")
    res = send_msg(sender, "headache")
    for r in res: print(f"Bot: {r.get('text', '')}")
    
    print("User: chest pain and can't breathe")
    res = send_msg(sender, "chest pain and can't breathe")
    for r in res:
        print(f"Bot: {r.get('text', '')}")
        if 'custom' in r:
            print(f"Bot JSON: {r['custom']}")

def run_test_2():
    print("\n--- Test 2: headache -> metadata -> follow-up -> emergency ---")
    sender = "test_2"
    print("User: headache + metadata(age=30, duration=2, severity=5)")
    res = send_msg(sender, "headache", {"age": 30, "duration": 2, "severity": 5})
    for r in res: print(f"Bot: {r.get('text', '')}")
    
    print("User: I can't breathe")
    res = send_msg(sender, "I can't breathe")
    for r in res:
        print(f"Bot: {r.get('text', '')}")
        if 'custom' in r:
            print(f"Bot JSON: {r['custom']}")

def run_test_3():
    print("\n--- Test 3: headache -> metadata -> deny -> continues ---")
    sender = "test_3"
    print("User: headache + metadata")
    res = send_msg(sender, "headache", {"age": 30, "duration": 2, "severity": 5})
    for r in res: print(f"Bot: {r.get('text', '')}")
    
    print("User: no")
    res = send_msg(sender, "no")
    for r in res:
        print(f"Bot: {r.get('text', '')}")
        if 'custom' in r:
            print(f"Bot JSON: {r['custom']}")

def run_test_4():
    print("\n--- Test 4: unsure confidence check ---")
    # First baseline: we just say 'yes' and 'no' to some symptoms.
    # Let's say user reports "rash".
    sender = "test_4a"
    print("--- Baseline (No unsure) ---")
    res = send_msg(sender, "rash", {"age": 30, "duration": 2, "severity": 5})
    for r in res: print(f"Bot: {r.get('text', '')}")
    
    # We get a question. Let's deny it.
    print("User: no")
    res = send_msg(sender, "no")
    for r in res:
        print(f"Bot: {r.get('text', '')}")
        if 'custom' in r and 'confidence' in r['custom']:
            print(f"Confidence: {r['custom']['confidence']}")
    
    # Now with unsure
    sender2 = "test_4b"
    print("\n--- Test (With unsure) ---")
    res = send_msg(sender2, "rash", {"age": 30, "duration": 2, "severity": 5})
    for r in res: print(f"Bot: {r.get('text', '')}")
    
    # We get the EXACT same question. Let's answer 'unsure'.
    print("User: unsure")
    res = send_msg(sender2, "unsure")
    for r in res:
        print(f"Bot: {r.get('text', '')}")
        if 'custom' in r and 'confidence' in r['custom']:
            print(f"Confidence: {r['custom']['confidence']}")

if __name__ == "__main__":
    time.sleep(2) # Give server a sec
    run_test_1()
    run_test_2()
    run_test_3()
    run_test_4()
