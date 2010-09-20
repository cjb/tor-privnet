import run_tors

teststr = """
A = 1

Tors("some_auths",
     N=99,
     capybara=False)

"""
envstr = """
B = 2
"""

testout, envout = run_tors.read_configurations(teststr, envstr)

assert testout['A'] == 1
assert envout['B'] == 2
print testout['A']
print envout['B']
assert "C" not in testout
assert testout['ALL_TORS'][0] == ("some_auths", {'N':99, 'capybara':False})
print "ok"

teststr = """

Tors("group", N=3, hi_mom="sure kid", torrc="")

Tors("group2", N=2, hi_mom="no", torrc="Bad Option Here")
"""

testout, envout = run_tors.read_configurations(teststr, envstr)

# XXXX Test group uniqueness check.

try:
    tors = run_tors.check_configurations(testout, envout)
    assert "This" == "Unreached"
except ValueError, v:
    print "ok"

import tempfile

root = tempfile.mkdtemp()

envstr = """
WORK_DIR = %r
""" % root

teststr = """

TEST_NAME = 'example'

Tors("group", N=3, hi_mom="sure kid", torrc="")

Tors("group2", N=2, hi_mom="no", torrc="Bad Option Here")
"""

testout, envout = run_tors.read_configurations(teststr, envstr)

tors = run_tors.check_configurations(testout, envout)
assert len(tors) == 5

run_tors.make_directories(tors, root)

import os

assert os.path.isdir(os.path.join(root,"001-group-001"))
assert os.path.isdir(os.path.join(root,"005-group2-002"))
#print os.listdir(root)
#print root
print "ok"






