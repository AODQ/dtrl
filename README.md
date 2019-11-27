# Damn Thicc Rendering Library




# Building

For now DTRL just builds as a testing application, until the library is mature
enough to warrant multiple test applications. To build DTRL, you need a D
compiler (DMD, LDC or GDC), DUB, GLFW and cimgui. All of these should be
provided by your package manager, with the exception of cimgui, which has to be
built/installed by hand from https://github.com/cimgui/cimgui .

ei

\# build cimgui
git clone https://github.com/cimgui/cimgui
pushd cimgui
mkdir build
cd build
cmake -DCMAKE\_BUILD\_TYPE=RelWithDebInfo ..
make -j3
sudo cp cimgui.so /usr/lib/cimgui.so
popd

\# build & runs dtrl
git clone https://github.com/aodq/dtrl
cd dtrl
git submodule update --init --recursive
dub
