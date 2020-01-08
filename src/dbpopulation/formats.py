def parse_format_1(fname):
    f = open(fname, "r")
    s = f.read()
    f.close()
    ssplit1 = s[:110].split("\n")
    lnsep = ssplit1[0]
    kvsep = ssplit1[1]
    ssplit1 = s[110:].split(lnsep)
    d = {}
    for ln in ssplit1:
            kv = ln.split(kvsep)
            d[kv[0]] = kv[1]
    return d

