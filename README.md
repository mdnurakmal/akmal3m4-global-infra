# akmal3m4-global-infra


# Instrctions
```
export CLOUDSDK_PYTHON_SITEPACKAGES=1

gcloud beta builds submit --config cloudbuild.yaml .
git pull
```


After cloud build , set iap to backend service

If there are existing resources , you need to import to terraform manually and try cloud build again