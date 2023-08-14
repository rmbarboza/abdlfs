#!/bin/sh

  grep -A 1 -B 1 -e '^# Upgraded' *.sh
  echo '--'
  grep -A 1 -e '^# Added' *.sh
  echo '--'
  grep -B 1 -e '^# Removed' *.sh

