import os
import errno
import binascii

# 0. Read configurations

def read_configurations(teststr, envstr):
    (testgdict, testldict) = (dict(), dict())
    (envgdict, envldict) = (dict(), dict())
    ALL_TORS = []
    def Tors(groupName, **kwargs):
        ALL_TORS.append((groupName, kwargs))
    testldict["ALL_TORS"] = ALL_TORS
    testldict["Tors"] = Tors

    exec teststr in testgdict, testldict
    exec envstr in envgdict, envldict

    return (testldict, envldict)

REQUIRED_TEST_FIELDS = set(["ALL_TORS", "TEST_NAME"])
REQUIRED_TORGROUP_FIELDS = set(["N", "torrc"])
REQUIRED_ENV_FIELDS = set(["WORK_DIR"])

# Fields in a Tors():
#
# In the configuration
#    N -- how many instances
#    torrc -- string, formattable: a torrc file's contents
#    isAuthority
#    isRouter
#    isClient
#    host
#    torBin -- 
#    torGencertBin --
#
# Added by this script
#    NUM
#    NUM_IN_GROUP
#    GROUP_NAME
#    INST_DIR
#
# Fields in the environment:
#    Something to list hosts?
#    Something to list Tor/Tor_gencert implementations

def check_configurations(testcfg, envcfg):
    for fld in REQUIRED_TEST_FIELDS:
        if fld not in testcfg:
            raise ValueError("Missing field %s in test configuration"%fld)
    for fld in REQUIRED_ENV_FIELDS:
        if fld not in envcfg:
            raise ValueError("Missing field %s in environment configuration"%fld)
    groupNameToCfg = {}
    for torgroupname, torgroupcfg in testcfg['ALL_TORS']:
        if torgroupname in groupNameToCfg:
            raise ValueError("Two groups with the same name: %s"% torgroupname)
        for fld in REQUIRED_TORGROUP_FIELDS:
            if fld not in torgroupcfg:
                raise ValueError("Missing field %s in Tor group %s"%(fld,torgroupname))
        groupNameToCfg[torgroupname] = torgroupcfg

    torInstances = []
    overallNum = 0
    for torgroupname, torgroupcfg in testcfg['ALL_TORS']:
        for num in xrange(1, torgroupcfg['N']+1):
            overallNum += 1
            cfg = torgroupcfg.copy()
            cfg['NUM'] = overallNum
            cfg['NUM_IN_GROUP'] = num
            cfg['GROUP_NAME'] = torgroupname
            torInstances.append(cfg)

    return torInstances

# 1. Make directory structures if needed

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError, e:
        if e.errno == errno.EEXIST:
            pass
        raise

def make_directories(torinstances, rootdir):
    for tor in torinstances:
        tor['INST_DIR'] = wd = os.path.join(rootdir, "%03d-%s-%03d"%
                                    (tor['NUM'], tor['GROUP_NAME'], tor['NUM_IN_GROUP']))
        mkdir_p(wd)

# 2. Generate authority keys and fingerprints (if needed)

def mk_password():
    return binascii.b2a_base64(os.urandom(16))

def make_one_authority_key(gencert_path, target_path, lifetime, address):
    j=os.path.join
    ID_KEY_FILE=j(target_path, "id_key")
    SIGNING_KEY_FILE=j(target_path, "signing_key")
    CERT_FILE=j(target_path, "cert")

    mkdir_p(target_path)

    passwd = mk_password()

    r,w = os.pipe()

    try:
        cmdline = [ gencert_path, "--create-identity-key",
                    "-i", ID_KEY_FILE, "-s", SIGNING_KEY_FILE,
                    "-c", CERT_FILE, "-m", str(lifetime), "-a", address,
                    "--passphrase-fd", str(r) ]

        process = subprocess.Popen(cmdline, close_fds=False)
        os.write(w, passwd)
        os.write(w, "\n")

        process.wait()
    finally:
        os.close(r)
        os.close(w)

def get_gencert_path(torinstance, envdict):
    return "tor-gencert" # implement multi-tor stuff later XXXX
 
def get_tor_path(torinstance, envdict):
    return "tor" # implement multi-tor stuff later XXXX

def make_authority_keys(torinstances, envdict):
    for tor in torinstances:
        if not tor.get('isAuthority', False):
            continue
        make_one_authority_key(
            get_gencert_path(tor, envdict),
            os.path.join(tor['INST_DIR'], "authority-keys"),
            12,#XXXX make the lifetime configurable
            "localhost:1234"#XXXX guess we needed to assign addresses earlier
            )

# 3. Generate config files
# 4. killall tor
# 5. Start tors (in the right order)
# 6. Inject some input
# 7. Wait for something cool to happen
