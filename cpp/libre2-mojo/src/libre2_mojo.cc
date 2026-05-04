#include "libre2_mojo.h"
#include <re2/re2.h>
#include <string>
#include <vector>

static_assert(sizeof(re2m_string_t) == 16,
              "re2m_string_t must be 16 bytes (LP64 only in V0)");

struct re2m_options { re2::RE2::Options inner; };
struct re2m_regexp  { re2::RE2 *re; std::string err; };

extern "C" {

re2m_options_t *re2m_opt_new(void) {
    auto *o = new re2m_options{};
    o->inner.set_encoding(re2::RE2::Options::EncodingUTF8);
    return o;
}
void re2m_opt_delete(re2m_options_t *o) { delete o; }
void re2m_opt_set_encoding(re2m_options_t *o, int32_t e) {
    o->inner.set_encoding(e == RE2M_LATIN1
        ? re2::RE2::Options::EncodingLatin1
        : re2::RE2::Options::EncodingUTF8);
}
void re2m_opt_set_log_errors(re2m_options_t *o, int32_t v)     { o->inner.set_log_errors(v != 0); }
void re2m_opt_set_case_sensitive(re2m_options_t *o, int32_t v) { o->inner.set_case_sensitive(v != 0); }
void re2m_opt_set_dot_nl(re2m_options_t *o, int32_t v)         { o->inner.set_dot_nl(v != 0); }

re2m_regexp_t *re2m_new(const char *p, int32_t plen, const re2m_options_t *o) {
    auto *r = new re2m_regexp{};
    /* Quiet (CannedOptions enum value) is implicitly converted to RE2::Options
     * via Options' converting constructor; suppresses stderr logging on parse
     * failure. We surface errors via re2m_error_code / re2m_error_string. */
    r->re = new re2::RE2(re2::StringPiece(p, plen), o ? o->inner : re2::RE2::Quiet);
    if (!r->re->ok()) r->err = r->re->error();
    return r;
}
void re2m_delete(re2m_regexp_t *r) { delete r->re; delete r; }

int32_t re2m_error_code(const re2m_regexp_t *r) {
    return r->re->ok() ? 0 : static_cast<int32_t>(r->re->error_code());
}
const char *re2m_error_string(const re2m_regexp_t *r) { return r->err.c_str(); }
int32_t re2m_num_capturing_groups(const re2m_regexp_t *r) {
    return static_cast<int32_t>(r->re->NumberOfCapturingGroups());
}

int32_t re2m_match(const re2m_regexp_t *r, const char *text, int32_t tlen,
                   int32_t sp, int32_t ep, int32_t anchor,
                   re2m_string_t *match, int32_t nmatch) {
    /* Reject negative bounds and out-of-range endpos: RE2::Match takes
     * size_t, where negative int32 silently wraps to ~2^64. The Mojo
     * binding never passes negatives in normal use, but this is the
     * load-bearing C ABI guard. */
    if (sp < 0 || ep < 0 || tlen < 0 || ep > tlen || nmatch < 0) return 0;

    re2::RE2::Anchor a = anchor == RE2M_ANCHOR_BOTH  ? re2::RE2::ANCHOR_BOTH
                       : anchor == RE2M_ANCHOR_START ? re2::RE2::ANCHOR_START
                                                    : re2::RE2::UNANCHORED;
    /* Stack-allocate small; heap if very large. nmatch is bounded by the
     * compiled pattern's group count + 1, typically < 16. */
    re2::StringPiece spans[64];
    re2::StringPiece *v = spans;
    std::vector<re2::StringPiece> heap;
    if (nmatch > 64) { heap.resize(nmatch); v = heap.data(); }

    bool ok = r->re->Match(re2::StringPiece(text, tlen),
                           static_cast<size_t>(sp), static_cast<size_t>(ep),
                           a, v, nmatch);
    if (!ok) return 0;
    for (int i = 0; i < nmatch; ++i) {
        match[i].data     = v[i].data();
        match[i].length   = static_cast<int32_t>(v[i].size());
        match[i]._padding = 0;
    }
    return 1;
}

} /* extern "C" */
