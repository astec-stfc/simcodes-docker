#!/bin/bash
# Smoke test of the simcodes image.  Run it inside the image:
#
#   docker run --rm -v "$PWD/.github/tests:/tests:ro" --entrypoint bash IMAGE /tests/smoke.sh
#
# Every code has to start and do one small real thing.  This is not a physics test (the integration tests of
# github.com/astec-stfc/simba-integration-tests compare the codes with each other through LAURA and SIMBA); it
# catches a code that no longer links, starts, initialises MPI or finds its data.  GPT is licensed and not in the image.
# A `warn` step reports a known problem without failing the run.
cd "$(mktemp -d)" || exit 1
failed=0
warned=0
step() {  # step NAME COMMAND...: the output is shown only when the command fails
    local name=$1; shift
    if out=$("$@" 2>&1); then echo "ok     $name"; else echo "FAILED $name"; echo "$out" | tail -n 12 | sed 's/^/         /'; failed=$((failed + 1)); fi
}
warn() {
    local name=$1; shift
    if out=$("$@" 2>&1); then echo "ok     $name"; else echo "WARN   $name"; echo "$out" | tail -n 6 | sed 's/^/         /'; warned=$((warned + 1)); fi
}

E=/simcodes/elegant/bin/Linux-x86_64
#### a small ring for the lattice codes: a FODO cell
cat > fodo.lte <<'EOF'
QF: QUAD, L=0.2, K1=1.5
QD: QUAD, L=0.2, K1=-1.5
D: DRIF, L=1.0
FODO: LINE=(QF, D, QD, D)
EOF
cat > track.ele <<'EOF'
&run_setup
 lattice = "fodo.lte", use_beamline = "FODO", p_central_mev = 100, rootname = "fodo",
 default_order = 1
&end
&run_control n_steps = 10 &end
&twiss_output filename = "%s.twi", matched = 1 &end
&bunched_beam n_particles_per_bunch = 1000, emit_x = 1e-9, emit_y = 1e-9, beta_x = 10, beta_y = 10, sigma_dp = 1e-3, sigma_s = 1e-3 &end
&track &end
EOF

#### compiled codes
step "elegant tracks a beam and writes its twiss file" bash -c "$E/elegant track.ele && test -s fodo.twi"
# Pelegant is linked against MPICH; its own mpiexec is the one that has to launch it
MPICH_MPIEXEC=$(dirname "$(ldd $E/Pelegant | awk '/libmpi/ {print $3; exit}')")/../bin/mpiexec
step "Pelegant tracks the same beam on 2 MPI ranks (MPICH mpiexec)" "$MPICH_MPIEXEC" -np 2 $E/Pelegant track.ele
warn "Pelegant with the mpiexec on PATH, which is what SIMBA's docker command uses" mpiexec --allow-run-as-root --oversubscribe -np 2 $E/Pelegant track.ele

cat > beam.in <<'EOF'
&INPUT
 FNAME = 'beam.ini', Add = F, N_add = 0, IPart = 1000, Species = 'electrons', Probe = T, Noise_reduc = T,
 High_res = T, Cathode = F, Q_total = 0.01, Ref_zpos = 0.0, Ref_clock = 0.0, Ref_Ekin = 5.0,
 Dist_z = 'g', sig_z = 0.5, Dist_pz = 'g', sig_Ekin = 0.01, Dist_x = 'g', sig_x = 0.5, Dist_px = 'g', Nemit_x = 0.5,
 Dist_y = 'g', sig_y = 0.5, Dist_py = 'g', Nemit_y = 0.5
/
EOF
cat > astra.in <<'EOF'
&NEWRUN
 Head = 'smoke', RUN = 1, Distribution = 'beam.ini', Lprompt = F, TRACK_ALL = T, H_max = 0.01
/
&OUTPUT
 ZSTART = 0, ZSTOP = 1, Zemit = 10, Zphase = 1, RefS = T, EmitS = T, PhaseS = T, LandFS = F
/
&CHARGE
 LSPCH = F
/
EOF
step "ASTRA generator writes a bunch" bash -c '/simcodes/Astra-serial/generator beam.in && test -s beam.ini'
step "ASTRA tracks it through a drift" bash -c '/simcodes/Astra-serial/Astra astra.in && test -s astra.Log.001'

# CSRTrack and Genesis need a full input deck to do anything real; here they have to start: some output, and an exit
# code that is not a loader failure or a crash (126 and up)
starts() {  # starts PATTERN COMMAND...
    local pattern=$1; shift
    out=$("$@" 2>&1); rc=$?
    [ $rc -lt 126 ] && echo "$out" | grep -qi "$pattern"
}
step "CSRTrack starts" bash -c "$(declare -f starts); starts 'csr' /simcodes/CSRTrack-serial/csrtrack_1.204_Linux_x86_64_serial"
step "Genesis 1.3 v4 starts" bash -c "$(declare -f starts); starts 'genesis' /simcodes/Genesis/genesis4 -h"

printf 'OPTION, INFO=FALSE;\nTITLE, STRING="smoke";\nValue, {1+1};\nSTOP;\n' > smoke.in
step "OPAL reports its version" bash -c '/simcodes/OPAL-install/bin/opal --version | grep -q 2024'
step "OPAL reads an input file (one process, as SIMBA runs it)" /simcodes/OPAL-install/bin/opal smoke.in
# {0} in the banner only appears when MPI has started more than one rank; the deck stops before MPI_Finalize, so mpirun
# complains on exit and only the banner can be checked
step "OPAL starts MPI on 2 ranks (OpenMPI 4.0.3 of the image)" bash -c \
    '/simcodes/openmpi-4.0.3-install/bin/mpirun --allow-run-as-root --oversubscribe -np 2 /simcodes/OPAL-install/bin/opal smoke.in 2>&1 | grep -q "OPAL{0}>"'

#### Python codes, in the image's own Python
step "Ocelot computes twiss" python -c "
from ocelot import Drift, Quadrupole, MagneticLattice, Twiss, twiss
lat = MagneticLattice([Quadrupole(l=0.2, k1=1.5), Drift(l=1.0), Quadrupole(l=0.2, k1=-1.5), Drift(l=1.0)])
tws = twiss(lat, Twiss(beta_x=10, beta_y=10)); assert len(tws) > 4"
step "MAD-X (cpymad) computes twiss" python -c "
from cpymad.madx import Madx
m = Madx(stdout=False)
m.input('qf: quadrupole, l=0.2, k1=1.5; qd: quadrupole, l=0.2, k1=-1.5; d: drift, l=1; fodo: line=(qf,d,qd,d);')
m.input('beam, particle=electron, energy=0.1; use, sequence=fodo;')
t = m.twiss(betx=10, bety=10); assert len(t.betx) > 3"
step "Xsuite computes a periodic twiss" python -c "
import xtrack as xt
line = xt.Line(elements=[xt.Quadrupole(length=0.2, k1=1.5), xt.Drift(length=1.0), xt.Quadrupole(length=0.2, k1=-1.5), xt.Drift(length=1.0)])
line.particle_ref = xt.Particles(p0c=1e9, mass0=xt.ELECTRON_MASS_EV)
tw = line.twiss(method='4d'); assert 0 < tw.qx < 1"
step "Cheetah tracks a beam" python -c "
import cheetah, torch
seg = cheetah.Segment([cheetah.Drift(length=torch.tensor(1.0)), cheetah.Quadrupole(length=torch.tensor(0.2), k1=torch.tensor(1.5))])
out = seg.track(cheetah.ParticleBeam.from_parameters(num_particles=torch.tensor(1000)))"
step "Wake-T imports" python -c "import wake_t"
cat > fodo.bmad <<'EOF'
beginning[beta_a] = 10
beginning[beta_b] = 10
beginning[p0c] = 1e8
parameter[particle] = electron
parameter[geometry] = open
qf: quadrupole, l = 0.2, k1 = 1.5
qd: quadrupole, l = 0.2, k1 = -1.5
d: drift, l = 1.0
fodo: line = (qf, d, qd, d)
use, fodo
EOF
step "Bmad (Tao) loads a lattice and computes twiss" python -c "
from pytao import Tao
tao = Tao('-lat fodo.bmad -noplot'); assert tao.lat_list('*', 'ele.name')"

#### the layout SIMBA finds the codes in when it runs inside the image (simcodes=$SIMCODES, no container runtime)
step "SIMCODES and TAO_DIR are set" bash -c 'test "$SIMCODES" = /simba-codes && test -d "$TAO_DIR"'
step "elegant and Pelegant are on PATH" bash -c 'command -v elegant && command -v Pelegant'
step "SIMBA's posix layout resolves every code" bash -c '
    for f in ASTRA/Astra ASTRA/generator CSRTrack/csrtrack_1.204_Linux_x86_64_serial Genesis/genesis4 OPAL/bin/opal Bmad/lib/libtao.so; do
        test -x "$SIMCODES/$f" || { echo "missing or not executable: $SIMCODES/$f"; exit 1; }
    done
    test -f "$SIMCODES/OPAL/etc/profile.d/opal.sh"'

echo
echo "$failed step(s) failed, $warned warning(s)"
exit $failed
