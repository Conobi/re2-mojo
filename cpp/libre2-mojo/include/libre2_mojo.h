#ifndef LIBRE2_MOJO_H
#define LIBRE2_MOJO_H

#include <stdint.h>

/* Visibility macro — paired with -fvisibility=hidden in CMakeLists.txt.
   Every exported symbol MUST carry RE2M_API or it will be hidden. */
#if defined(__GNUC__) || defined(__clang__)
#  define RE2M_API __attribute__((visibility("default")))
#else
#  define RE2M_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handles */
typedef struct re2m_options re2m_options_t;
typedef struct re2m_regexp  re2m_regexp_t;

/* Capture span — pointer + length into the input text. Layout is fixed
 * and load-bearing: the Mojo binding indexes match[] arrays at
 * slot_bytes=16 stride. _padding makes the layout portable across
 * x86-64 LP64 and AArch64 LP64. */
typedef struct {
    const char *data;
    int32_t     length;
    int32_t     _padding;
} re2m_string_t;

/* Encoding constants */
#define RE2M_UTF8    1
#define RE2M_LATIN1  2

/* Anchor constants — value-compatible with cre2's enum (1/2/3).
 * Internally re2m_match maps these to RE2's enum (0/1/2). */
#define RE2M_UNANCHORED   1
#define RE2M_ANCHOR_START 2
#define RE2M_ANCHOR_BOTH  3

/* Options */
RE2M_API re2m_options_t *re2m_opt_new(void);
RE2M_API void            re2m_opt_delete(re2m_options_t *opt);
RE2M_API void            re2m_opt_set_encoding(re2m_options_t *opt, int32_t encoding);
RE2M_API void            re2m_opt_set_log_errors(re2m_options_t *opt, int32_t log_errors);
RE2M_API void            re2m_opt_set_case_sensitive(re2m_options_t *opt, int32_t case_sensitive);
RE2M_API void            re2m_opt_set_dot_nl(re2m_options_t *opt, int32_t dot_nl);

/* Regexp lifecycle */
RE2M_API re2m_regexp_t *re2m_new(const char *pattern, int32_t pattern_length, const re2m_options_t *opt);
RE2M_API void           re2m_delete(re2m_regexp_t *re);
RE2M_API int32_t        re2m_error_code(const re2m_regexp_t *re);
RE2M_API const char    *re2m_error_string(const re2m_regexp_t *re);
RE2M_API int32_t        re2m_num_capturing_groups(const re2m_regexp_t *re);

/* Match: returns 1 on hit, 0 on miss. match[] receives capture spans:
 * match[0] = full match; match[1..nmatch-1] = group 1..nmatch-1.
 * Slots whose group did not participate get {data=NULL, length=0}. */
RE2M_API int32_t re2m_match(
    const re2m_regexp_t *re,
    const char          *text,
    int32_t              text_length,
    int32_t              start_pos,
    int32_t              end_pos,
    int32_t              anchor,
    re2m_string_t       *match,
    int32_t              nmatch
);

#ifdef __cplusplus
}
#endif
#endif /* LIBRE2_MOJO_H */
