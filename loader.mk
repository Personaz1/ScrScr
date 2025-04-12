CXX = g++
CXXFLAGS = -shared -fPIC -std=c++11 -Wall
LDFLAGS = -ldl

TARGET = libloader.so
SOURCES = loader.cpp
HEADERS = 

all: $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ $(SOURCES) $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p /usr/lib
	cp $(TARGET) /usr/lib/
	touch /tmp/ssh_loader.dbg
	chmod 666 /tmp/ssh_loader.dbg
	@echo "Installed $(TARGET) to /usr/lib/"
	@echo "Created log file: /tmp/ssh_loader.dbg"

.PHONY: all clean install 