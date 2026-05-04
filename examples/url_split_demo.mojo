# url_split_demo — generic regex showcase using compile() + match + group access.
# Splits URLs into scheme / host / path. Run via Mojo MCP execute.

from re2_mojo import compile

def main() raises:
    var pat = compile(String("([a-z]+)://([^/]+)(/.*)?"))
    var inputs = List[String]()
    inputs.append(String("https://example.com/path/to/thing"))
    inputs.append(String("ftp://archive.example.org"))
    inputs.append(String("ws://localhost:8080/socket"))
    for i in range(len(inputs)):
        var url = inputs[i]
        var m = pat.match(url)
        if not m:
            print("no match:", url)
            continue
        var mm = m.value().copy()
        print("URL:", url)
        print("  scheme:", mm.group(1))
        print("  host:  ", mm.group(2))
        print("  path:  ", mm.group(3))
