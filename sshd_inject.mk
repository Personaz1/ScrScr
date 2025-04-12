CXX = g++
CXXFLAGS = -shared -fPIC -std=c++11 -Wall
LDFLAGS = -ldl

TARGET = libsshd_inject.so
SOURCES = sshd_inject.cpp
HEADERS = 

all: $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ $(SOURCES) $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p /usr/lib
	cp $(TARGET) /usr/lib/
	touch /tmp/sshd_inj.dbg
	chmod 666 /tmp/sshd_inj.dbg
	@echo "Installed $(TARGET) to /usr/lib/"
	@echo "Created log file: /tmp/sshd_inj.dbg"

.PHONY: all clean install 