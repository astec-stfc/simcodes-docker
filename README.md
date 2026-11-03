# Docker/apptainer version of simcodes for SIMBA

The simulation codes that [SIMBA](https://github.com/astec-stfc/simba) drives, in one image
(`ghcr.io/astec-stfc/simcodes-docker:<tag>`, built by `.github/workflows/deploy.yaml`, which also flattens it to an
Apptainer image). With it a machine needs Docker and nothing else, except for GPT.

## Available codes

Compiled, under `/simcodes`:

 * [Elegant](https://github.com/rtsoliday/elegant) and Pelegant (with [SDDS](https://github.com/rtsoliday/SDDS))
 * [CSRTrack](https://www.desy.de/xfel-beam/csrtrack/)
 * [ASTRA](https://www.desy.de/~mpyflo/), serial and parallel
   * [OpenMPI 4.0.3](https://www.open-mpi.org/software/ompi/v4.0/)
 * [OPAL](https://github.com/OPALX-project/OPAL.git)
   * [H5Hut](https://github.com/eth-cscs/h5hut) Not authorative
 * [Genesis](https://github.com/svenreiche/Genesis-1.3-Version4)

Python, in the image's own Python (`/opt/conda/bin/python`, first on `PATH`):

 * [Bmad](https://www.classe.cornell.edu/bmad/) with Tao, through `pytao`
 * [Ocelot](https://github.com/ocelot-collab/ocelot), [Xsuite](https://github.com/xsuite), [Cheetah](https://github.com/desy-ml/cheetah),
   [Wake-T](https://github.com/AngelFP/Wake-T) and [MAD-X](https://github.com/MethodicalAcceleratorDesign/MAD-X) through `cpymad`

[GPT](https://www.pulsar.nl/gpt/) is licensed and is not in the image.

## Using it

From SIMBA on the host, with the compiled codes in the image (the Python codes then run in the host's Python):

```python
Framework(directory=..., container_runtime="docker")   # SIMBA runs `docker run ... ghcr.io/astec-stfc/simcodes-docker:master`
```

Inside the image, with SIMBA installed into the image's Python: nothing runs in a second container, and the Python
codes are the image's. `SIMCODES=/simba-codes` holds links named as SIMBA expects its `posix` layout (`ASTRA/Astra`,
`CSRTrack/...`, `OPAL/bin/opal`, `Genesis/genesis4`, `Bmad/lib/libtao.so`), `elegant` and `Pelegant` are on `PATH`, and
`TAO_DIR` is set:

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
   `mpiexec -np 2 Pelegant` fails. `/usr/lib64/mpich/bin/mpiexec` launches it. SIMBA's docker command for Pelegant uses `mpiexec`
   from `PATH`. The smoke test reports this as a warning.
