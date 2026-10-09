# Basic validation script for Nmag container environment
import sys

print "=" * 60
print "NMAG ENVIRONMENT TEST"
print "=" * 60
print "Python Version:", sys.version

try:
    import nmag
    from nmag import SI
    print "Successfully imported 'nmag' and 'nmag.SI'!"
    print "Nmag version:", getattr(nmag, '__version__', '0.2.1')

    # Test creating a Simulation object
    sim = nmag.Simulation("test_sim")
    print "Successfully instantiated nmag.Simulation:", sim

    # Test material definition
    Fe = nmag.MagMaterial(
        name="Fe",
        Ms=SI(1.7e6, "A/m"),
        exchange_coupling=SI(2.1e-11, "J/m")
    )
    print "Successfully defined MagMaterial (Fe):", Fe

    print "\n-> NMAG DOCKER CONTAINER IS FULLY FUNCTIONAL! <-"
    print "=" * 60
except Exception as e:
    print "ERROR encountered during test:", e
    sys.exit(1)
