require 'spec_helper'

RSpec.shared_context "cli filter" do
  let(:filter) { 'mywork' }
  before :each do
    VCR.use_cassette(filter) do
      run "bin/pt #{filter}"
      stop_all_commands
    end
  end
end

describe PT::CLI, type: :aruba do
  let(:title) { 'random' }
  describe 'pt mywork' do
    before :each do
      VCR.use_cassette('my work') do
        run 'bin/pt'
        stop_all_commands
      end
    end
    it { expect(last_command_started.output).to include 'My Work' }
    it { expect(last_command_started.output).to include 'Kris' }
  end

  describe 'pt bug' do
    include_context 'cli filter' do
      let(:filter) { 'bug' }
    end
    it {expect(last_command_started.output).not_to include "⭐"}
    it { expect(last_command_started.output).to include "🐞" }
  end

  describe 'shows feature' do
    include_context 'cli filter' do
      let(:filter) { 'feature' }
    end
    it {expect(last_command_started.output).to include "⭐"}
    it { expect(last_command_started.output).not_to include "🐞" }
  end

  filters = %w[unscheduled started finished delivered rejected]
  filters.each_with_index do |state, index|
    describe "pt #{state}" do
      include_context 'cli filter' do
        let(:filter) { state }
      end
      it {expect(last_command_started.output).to include state}
    end
  end

  describe "pt create" do
    context 'with title' do
      before do
        VCR.use_cassette('create with title parameter') do
          run "bin/pt create #{title}"
        end
        stop_all_commands
      end

      it {expect(last_command_started.output).to include title}
    end

    context 'without title' do
      before do
        VCR.use_cassette('create without title parameter') do
          run "bin/pt create"
        end
        type 'title<CR>'
        stop_all_commands
      end

      it { expect(last_command_started.output).to include 'assign'}
    end
  end

  PT::CLI::ACTION.each do |action|
    describe "pt #{action}" do
      include_context 'cli filter' do
        let(:filter) { action }
      end
      it {expect(last_command_started.output).to include action}
    end
  end

  describe 'pt find <query>' do
    before :each do
      VCR.use_cassette('find') do
        run "bin/pt find #{title}"
      end
      stop_all_commands
    end
    it {expect(last_command_started.output).to include title}
  end
end
