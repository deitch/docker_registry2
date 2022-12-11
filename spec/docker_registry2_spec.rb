# frozen_string_literal: true

require_relative '../lib/docker_registry2'

RSpec.describe DockerRegistry2 do
  let(:connected_object) { described_class.connect('http://localhost:5000') }

  describe '.connect' do
    it { expect { connected_object }.not_to raise_error }
    it { expect(connected_object).not_to be_nil }
  end

  describe '.tags' do
    let(:tags_hello_world_v1) do
      VCR.use_cassette('tags/hello-world-v1') { connected_object.tags('hello-world-v1') }
    end
    let(:tags_hello_world_v99) do
      VCR.use_cassette('tags/hello-world-v99') { connected_object.tags('hello-world-v99') }
    end

    context 'tag exist' do
      it { expect { tags_hello_world_v1 }.not_to raise_error }
      it { expect(tags_hello_world_v1).not_to be_nil }
      it { expect(tags_hello_world_v1.keys).to contain_exactly('tags', 'name') }
      it { expect(tags_hello_world_v1['tags']).to eq ['latest'] }
      it { expect(tags_hello_world_v1['name']).to eq 'hello-world-v1' }
    end

    context 'tag doesnt exist' do
      it { expect { tags_hello_world_v99 }.to raise_error(DockerRegistry2::NotFound) }
    end
  end

  describe 'manifest' do
    let(:manifest_hello_world_v1_latest) do
      VCR.use_cassette('manifest/hello-world-v1_latest') { connected_object.manifest('hello-world-v1', 'latest') }
    end

    let(:manifest_hello_world_v1_non_existent) do
      VCR.use_cassette('manifest/hello-world-v1_non_existent') do
        connected_object.manifest('hello-world-v1', 'non_existent')
      end
    end

    let(:manifest_hello_world_v99_latest) do
      VCR.use_cassette('manifest/hello-world-v99_latest') { connected_object.manifest('hello-world-v99', 'latest') }
    end

    context 'manifest exists' do
      it { expect { manifest_hello_world_v1_latest }.not_to raise_error }
    end

    context 'manifest for wrong tag' do
      it { expect { manifest_hello_world_v1_non_existent }.to raise_error(DockerRegistry2::NotFound) }
    end
    context 'manifest for wrong image' do
      it { expect { manifest_hello_world_v99_latest }.to raise_error(DockerRegistry2::NotFound) }
    end
  end
end
