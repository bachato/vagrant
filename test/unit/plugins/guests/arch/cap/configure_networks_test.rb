# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

require_relative "../../../../base"

describe "VagrantPlugins::GuestArch::Cap::ConfigureNetworks" do
  let(:caps) do
    VagrantPlugins::GuestArch::Plugin
      .components
      .guest_capabilities[:arch]
  end

  let(:guest) { double("guest") }
  let(:machine) { double("machine", guest: guest) }
  let(:comm) { VagrantTests::DummyCommunicator::Communicator.new(machine) }

  before do
    allow(machine).to receive(:communicate).and_return(comm)
  end

  after do
    comm.verify_expectations!
  end

  describe ".configure_networks" do
    let(:cap) { caps.get(:configure_networks) }

    before do
      allow(guest).to receive(:capability).with(:network_interfaces)
        .and_return(["eth1", "eth2"])
      allow(cap).to receive(:systemd_networkd?).and_return(true)
      allow(cap).to receive(:systemd_network_manager?).and_return(false)
    end

    let(:network_1) do
      {
        interface: 0,
        type: "dhcp",
      }
    end

    let(:network_2) do
      {
        interface: 1,
        type: "static",
        ip: "33.33.33.10",
        netmask: "255.255.0.0",
        gateway: "33.33.0.1",
      }
    end

    it "creates and starts the networks" do
      cap.configure_networks(machine, [network_1, network_2])
      expect(comm.received_commands[0]).to match(/chmod 0644 '(.+)'/)
      expect(comm.received_commands[0]).to match(/mv (.+) '\/etc\/systemd\/network\/eth1.network'/)
      expect(comm.received_commands[0]).to match(/networkctl reload/)

      expect(comm.received_commands[0]).to match(/chmod 0644 '(.+)'/)
      expect(comm.received_commands[0]).to match(/mv (.+) '\/etc\/systemd\/network\/eth2.network'/)
      expect(comm.received_commands[0]).to match(/networkctl reload/)
    end

    it "should not extraneous && joiners" do
      cap.configure_networks(machine, [network_1, network_2])
      expect(comm.received_commands[0]).not_to match(/^\s*&&\s*$/)
    end

    context "network is not contolled by systemd" do
      before do
        allow(cap).to receive(:systemd_networkd?).and_return(false)
      end

      it "creates and starts the networks" do
        cap.configure_networks(machine, [network_1, network_2])
        expect(comm.received_commands[0]).to match(/mv (.+) '\/etc\/netctl\/eth1'/)
        expect(comm.received_commands[0]).to match(/ip link set 'eth1' down/)
        expect(comm.received_commands[0]).to match(/netctl restart 'eth1'/)
        expect(comm.received_commands[0]).to match(/netctl enable 'eth1'/)
        expect(comm.received_commands[0]).to match(/mv (.+) '\/etc\/netctl\/eth2'/)
        expect(comm.received_commands[0]).to match(/ip link set 'eth2' down/)
        expect(comm.received_commands[0]).to match(/netctl restart 'eth2'/)
        expect(comm.received_commands[0]).to match(/netctl enable 'eth2'/)
      end
    end

    context "network is controlled by NetworkManager via systemd" do
      before do
        expect(cap).to receive(:systemd_network_manager?).and_return(true)
      end

      it "should configure for network manager" do
        expect(cap).to receive(:configure_network_manager).with(machine, [network_1])

        cap.configure_networks(machine, [network_1])
      end
    end
  end
end
