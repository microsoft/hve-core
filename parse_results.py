import re
import sys

content = open(sys.argv[1]).read()
sections = [
    ("lint:md", r"---TESTPY---"),
    ("---TESTPY---", r"---FRONTMATTER---"),
    ("---FRONTMATTER---", r"---LINTPY---"),
    ("---LINTPY---", r"---COLLMETA---"),
    ("---COLLMETA---", r"---MARKETPLACE---"),
    ("---MARKETPLACE---", None)
]

def check_fail(text):
    if "ERR!" in text or "error" in text.lower() or "failed" in text.lower() or "FAILED" in text:
        return "FAIL"
    return "PASS"

for start, end in sections:
    try:
        if end:
            chunk = content.split(start)[1].split(end)[0]
        else:
            chunk = content.split(start)[1]
        print(f"{start}: {check_fail(chunk)}")
    except:
        print(f"{start}: NOT FOUND")
