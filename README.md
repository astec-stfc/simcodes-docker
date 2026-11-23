# Docker/apptainer version of simcodes for SIMBA

The simulation codes that [SIMBA](https://github.com/astec-stfc/simba) drives, in one image
(`ghcr.io/astec-stfc/simcodes-docker:<tag>`, built by `.github/workflows/deploy.yaml`, which also flattens it to an
Apptainer image). With it a machine needs Docker and nothing else, except for GPT.

The codes are compiled in a `build` stage; the image keeps only their install trees and the libraries they link
(about 7 GB, most of it the conda environment). Running the workflow by hand on `master` publishes `:master`, which
moves; publishing a GitHub release publishes `:<release tag>`, which does not, so pin that for reproducible runs.

## Available codes

Compiled, under `/simcodes`:

 * [Elegant](https://github.com/rtsoliday/elegant) and Pelegant (with [SDDS](https://github.com/rtsoliday/SDDS))
 * [CSRTrack](https://www.desy.de/xfel-beam/csrtrack/)
 * [ASTRA](https://www.desy.de/~mpyflo/), serial and parallel
   * [OpenMPI 4.0.3](https://www.open-mpi.org/software/ompi/v4.0/)
 * [OPAL](https://github.com/OPALX-project/OPAL.git)
   * [H5Hut](https://github.com/eth-cscs/h5hut) Not authorative
 * [Genesis](https://github.com/svenreiche/Genesis-1.3-Version4)
 * [HiPACE++](https://github.com/Hi-PACE/hipace) (conda-forge, CPU with OpenMP, in its own conda environment), `hipace` on `PATH`
 * [Ptarmigan](https://github.com/tgblackburn/ptarmigan) (serial, with HDF5 output), `ptarmigan` on `PATH`

Python, in the image's own Python (`/opt/conda/bin/python`, first on `PATH`):

 * [Bmad](https://www.classe.cornell.edu/bmad/) with Tao, through `pytao`
 * [SIMBA](https://github.com/astec-stfc/simba) itself (the latest release at build time), with its `simcodes` and
   `fbpic` extras: [Ocelot](https://github.com/ocelot-collab/ocelot), [Xsuite](https://github.com/xsuite),
   [Cheetah](https://github.com/desy-ml/cheetah), [Wake-T](https://github.com/AngelFP/Wake-T),
   [MAD-X](https://github.com/MethodicalAcceleratorDesign/MAD-X) through `cpymad` and [FBPIC](https://github.com/fbpic/fbpic)
   (on the CPU), at the versions that SIMBA release asks for (`--build-arg SIMBA_SPEC=...` picks another)
 * [ImpactX](https://github.com/BLAST-ImpactX/impactx) (conda-forge, without MPI)
 * [Slipstream](https://github.com/astec-stfc/slipstream) (a GitHub release, `--build-arg SLIPSTREAM_VERSION=...`)

The conda-forge builds of ImpactX and HiPACE++ need an x86-64-v3 (AVX2) CPU.

Not in the image:

 * [GPT](https://www.pulsar.nl/gpt/), which is licensed
 * [RF-Track](https://gitlab.cern.ch/rf-track): its licence (CERN proprietary) allows free use but does not say it may
   be redistributed; `pip install RF_Track` puts it in the image's Python (or the host's)
 * [BDSIM](https://github.com/bdsim-collaboration/bdsim): it needs Geant4 and ROOT, which would make the image several
   GB larger

## Using it

From SIMBA on the host, with the compiled codes in the image (the Python codes, ImpactX, FBPIC, Slipstream and Bmad
included, then run in the host's Python, so they have to be installed there):

```python
Framework(directory=..., container_runtime="docker")   # SIMBA runs `docker run ... ghcr.io/astec-stfc/simcodes-docker:<tag>`
```

Inside the image, with the image's SIMBA: nothing runs in a second container, and the Python
codes are the image's. `SIMCODES=/simba-codes` holds links named as SIMBA expects its `posix` layout (`ASTRA/Astra`,
`CSRTrack/...`, `OPAL/bin/opal`, `Genesis/genesis4`, `Bmad/lib/libtao.so`), `elegant`, `Pelegant`, `ptarmigan` and
`hipace` are on `PATH`, and `TAO_DIR` is set:

```python
Framework(directory=..., simcodes=os.environ["SIMCODES"])   # no container_runtime
```

## Testing the image

`.github/tests/smoke.sh` starts every code and makes it do one small real thing (a tracked beam, a twiss, an MPI start).
The workflow runs it on the freshly built image before the image is pushed; by hand:

```bash
docker run --rm -v "$PWD/.github/tests:/tests:ro" --entrypoint bash IMAGE /tests/smoke.sh
```

It is not a physics test: the [integration tests](https://github.com/astec-stfc/simba-integration-tests) compare the codes with each other.

## ASTRA and CSRTrack when DESY is down

Both are only distributed from DESY's user pages, which are down at times. The Dockerfile runs `.github/docker/fetch-desy.sh` for
each file: it downloads it and keeps the download only if its sha256 is the one in [`vendor/desy/SHA256SUMS`](vendor/desy/);
if DESY does not answer, or answers with another file, it uses the known-good copy in `vendor/desy` and prints a warning
(`fetch-desy: WARNING ...`) in the build log. A build gives the same image either way, on GitHub as anywhere else.
`--build-arg FETCH_DESY_SKIP=1` does not try DESY at all. See [`vendor/desy/README.md`](vendor/desy/README.md) for where the
files came from and how to replace one.

## Known issues

 * Pelegant is linked against MPICH, but the `mpiexec` first on `PATH` is the OpenMPI 5 one of the conda environment, so
   `mpiexec -np 2 Pelegant` fails. `/usr/lib64/mpich/bin/mpiexec` launches it, and is what SIMBA's `Executables.yaml` uses
   (SIMBA versions that still call plain `mpiexec` cannot run Pelegant in the image).
