# lexer_table_demo — store many SharedPatterns in a List, scan input
# rule-by-rule (the shape dixi-parse's lexer will use after plan-5b).

from re2_mojo import compile_shared, SharedPattern

struct _Rule(Copyable, Movable):
    var name: String
    var pattern: SharedPattern

    def __init__(out self, name: String, var pattern: SharedPattern):
        self.name = name
        self.pattern = pattern^

def main() raises:
    var rules = List[_Rule]()
    rules.append(_Rule(String("INT"), compile_shared(String("\\d+"))))
    rules.append(_Rule(String("WORD"), compile_shared(String("[A-Za-z_]+"))))
    rules.append(_Rule(String("WS"), compile_shared(String("\\s+"))))

    var input = String("hello 42 world 99")
    var pos = 0
    while pos < input.byte_length():
        var matched = False
        for i in range(len(rules)):
            var m = rules[i].pattern.match(input, pos)
            if m:
                var mm = m.value().copy()
                if mm.end(0) > pos:  # non-empty match
                    print(rules[i].name, ":", mm.group(0))
                    pos = mm.end(0)
                    matched = True
                    break
        if not matched:
            print("no rule matched at pos", pos)
            break
