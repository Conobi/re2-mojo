#include "libre2_mojo.h"
#include <re2/re2.h>

static_assert(sizeof(re2m_string_t) == 16,
              "re2m_string_t must be 16 bytes (LP64 only in V0)");

struct re2m_options { re2::RE2::Options inner; };

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

} /* extern "C" */
