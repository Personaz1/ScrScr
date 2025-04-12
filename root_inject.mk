CXX = g++
CXXFLAGS = -shared -fPIC -std=c++11 -Wall -O2
LDFLAGS = -ldl

TARGET = libssh_root_inject.so
SOURCE = root_inject.cpp

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGET)

.PHONY: all clean 