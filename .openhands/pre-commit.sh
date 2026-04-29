#!/bin/bash

ruff check .
ty check .
basedpyright .
pytest .
