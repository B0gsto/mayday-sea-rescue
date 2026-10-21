// Root daemon: a virtual HID keyboard (Karabiner DriverKit) that games read like a real one.
// Reads lines from /tmp/rbxkeyd.fifo: "set <hid usage> ..." = the full set of keys held now ("set" alone = none).
// Usages 0xE0-0xE7 are modifiers. Built and started by tools/roblox/keyd.sh (needs sudo once).
#include <pqrs/karabiner/driverkit/virtual_hid_device_driver.hpp>
#include <pqrs/karabiner/driverkit/virtual_hid_device_service.hpp>
#include <atomic>
#include <fstream>
#include <iostream>
#include <sstream>
#include <sys/stat.h>

namespace hr = pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report;

int main() {
  pqrs::dispatcher::extra::initialize_shared_dispatcher();
  std::atomic<bool> ready(false);
  auto client = std::make_unique<pqrs::karabiner::driverkit::virtual_hid_device_service::client>();
  client->connected.connect([&client] {
    pqrs::karabiner::driverkit::virtual_hid_device_service::virtual_hid_keyboard_parameters p;
    p.set_country_code(pqrs::hid::country_code::us);
    client->async_virtual_hid_keyboard_initialize(p);
  });
  client->virtual_hid_keyboard_ready.connect([&ready](auto&& r) {
    if (r && !ready) std::cout << "keyboard ready" << std::endl;
    ready = r;
  });
  client->connect_failed.connect([](auto&& e) { std::cout << "connect_failed " << e << std::endl; });
  client->async_start();

  const char* path = "/tmp/rbxkeyd.fifo";
  unlink(path);
  mkfifo(path, 0666);
  chmod(path, 0666);
  for (;;) {
    std::ifstream in(path);  // blocks until a writer opens it
    std::string line;
    while (std::getline(in, line)) {
      std::istringstream ss(line);
      std::string cmd;
      ss >> cmd;
      if (cmd != "set") continue;
      hr::keyboard_input report;
      unsigned u;
      while (ss >> u) {
        if (u >= 0xE0 && u <= 0xE7) report.modifiers.insert(static_cast<hr::modifier>(1u << (u - 0xE0)));
        else report.keys.insert(u);
      }
      if (ready) client->async_post_report(report);
      else std::cout << "not ready, dropped: " << line << std::endl;
    }
  }
}
