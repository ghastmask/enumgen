enumgen
=======

Ruby DSL for creating better enums in c++.

This work is based off Chris Uzdavinis enumgen (https://code.google.com/p/enumgen/) but
updated for c++11 and hopefully more extensible. It does not have all the features but
most of the important ones such as mapping from strings to the enumerated types and
back to a string and providing insertion and extraction operators.

Most functionality should be easy to change to suit your needs by overriding the base
Cpp\_Writer object.
