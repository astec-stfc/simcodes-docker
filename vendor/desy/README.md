# Known-good copies of the DESY binaries

ASTRA and CSRTrack are only distributed from DESY's user pages, which are down at times. `fetch-desy` (in
`.github/docker/`) uses these copies when a download fails or does not match `SHA256SUMS`.

| file | from |
|------|------|
| `astra-serial/Astra`, `astra-serial/generator` | https://www.desy.de/~mpyflo/Astra_for_64_Bit_Linux/ |
| `astra-parallel/Astra` | https://www.desy.de/~mpyflo/Parallel_Astra_for_Linux/ |
| `csrtrack-serial/csrtrack_1.204_Linux_x86_64_serial`, `csrtrack-parallel/csrtrack_1.204_Linux_x86_64_OpenMPI_1.4.3` | https://www.desy.de/xfel-beam/csrtrack/files/ |

These were copied out of `ghcr.io/astec-stfc/simcodes-docker:master` as built on 2026-08-12
(`sha256:768479cf7f13e46c9c8877a763069a258cdc1ea7a66bf4ae43ee9aec6b53cf94`, linux/amd64). That build downloaded them
from the URLs above, so they are DESY's files as of that date.

## Replacing one

When DESY publishes a new version, download it, put it here under the same name, and update its line in `SHA256SUMS`
(`sha256sum <rel>` from this directory). Until then a build keeps using this copy and prints a
`fetch-desy: WARNING ... differs from the known-good file` line, so new versions show up in the build log.
