#!/bin/bash
kind get clusters
kind delete cluster --name=$(kind get clusters )
rm -f init-keys_k*.json  worker*.yaml

