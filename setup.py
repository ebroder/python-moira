#!/usr/bin/python

from setuptools import setup
from distutils.extension import Extension
from Pyrex.Distutils import build_ext

setup(
    name="PyMoira",
    version="1.0.0",
    description="PyMoira - Python bindings for the Athena Moira library",
    author="Evan Broder",
    author_email="broder@mit.edu",
    ext_modules=[
        Extension("moira",
                  ["moira.pyx"],
                  libraries=["moira", "krb5", "krb4", "hesiod"])
        ],
    cmdclass= {"build_ext": build_ext}
)
