# ipa-cert-exporter

Go exporter that exposes FreeIPA certificate expiry as Prometheus metrics.
Everything in the lab is signed by FreeIPA's internal Dogtag CA (no public
ACME for `.internal`), so certificate expiry is the lab's most realistic
failure mode — this exporter, its alert, and the renewal runbook exist to
catch it. Arrives at M4 with tests and a multi-arch release.
