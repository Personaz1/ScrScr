CXX = g++
CXXFLAGS = -shared -fPIC -std=c++11 -Wall
LDFLAGS = -ldl

TARGET = libssh_inject.so
SOURCES = ssh_inject.cpp
HEADERS = state.hpp

all: $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ $(SOURCES) $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p /usr/lib
	cp $(TARGET) /usr/lib/
	touch /tmp/ssh_inj.dbg
	chmod 666 /tmp/ssh_inj.dbg
	@echo "Installed $(TARGET) to /usr/lib/"
	@echo "Created log file: /tmp/ssh_inj.dbg"

test: $(TARGET)
	LD_PRELOAD=./$(TARGET) ssh localhost

.PHONY: all clean install test 