# Laboratoires pour le cours de System on chip

# Information utiles

[Documentation Cyclone V](https://docs.altera.com/r/docs/683126/21.2/cyclone-v-hard-processor-system-technical-reference-manual/cyclone-v-hard-processor-system-technical-reference-manual-revision-history)

[Map d'address Cyclone V](https://www.intel.com/content/www/us/en/programmable/hps/cyclone-v/hps.html)

# Script pour programmer la FPGA

```bash
python3 pgm_fpga.py -s=/media/sf_vmShare/scf_labs/labo1/hps_gpio/hard/eda/output_files/Lab01.sof
```

Changer le chemin vers le fichier .sof selon votre configuration

Preloader

```bash
python3 upld_hps.py
```