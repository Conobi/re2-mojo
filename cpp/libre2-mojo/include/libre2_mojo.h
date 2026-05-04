#ifndef LIBRE2_MOJO_H
#define LIBRE2_MOJO_H

#if defined(__GNUC__) || defined(__clang__)
#define RE2M_API __attribute__((visibility("default")))
#else
#define RE2M_API
#endif

#ifdef __cplusplus
extern "C" {
#endif
/* Placeholder — Task 2 fills this. */
RE2M_API int re2m_smoke(void);
#ifdef __cplusplus
}
#endif
#endif
