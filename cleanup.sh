#!/bin/bash
kind get clusters
kind delete cluster --name=$(kind get clusters )
rm -f nit-keys_k*.json  worker*.yaml

