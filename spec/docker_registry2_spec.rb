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

  describe 'search' do
    let(:search_hello_world) do
      VCR.use_cassette('search/hello_world') { connected_object.search('hello-world') }
    end
    it { expect { search_hello_world }.not_to raise_error }
    it { expect(search_hello_world.size).to eq 2 }
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

    let(:my_ubuntu_multiarch_manifest) do
      VCR.use_cassette('manifest/multiarch_ubuntu') { connected_object.manifest('my-ubuntu', '17.04') }
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

    context 'multiarch manifest exists' do
      it { expect { my_ubuntu_multiarch_manifest }.not_to raise_error }
    end

    context 'multiarch manifest returns the expected archs' do
      let(:archs) do
        my_ubuntu_multiarch_manifest.fetch('manifests').map { |manifest| manifest.fetch('platform').fetch('architecture') }
      end

      it { expect { my_ubuntu_multiarch_manifest }.not_to raise_error }
      it { expect(archs).to match_array(%w[amd64 arm64]) }
    end

    context 'Docker registry without path' do
      let(:uri) { 'https://example.com' }
      let(:registry) { DockerRegistry2::Registry.new(uri) }

      it 'The @path should be empty' do
        expect(registry.instance_variable_get(:@base_uri)).to eq('https://example.com:443')
      end
    end

    context 'Docker registry with a @path' do
      let(:uri) { 'https://registry.myCompany.com/dockerproxy' }
      let(:registry) { DockerRegistry2::Registry.new(uri) }

      it 'The @path is included' do
        expect(registry.instance_variable_get(:@base_uri)).to eq('https://registry.myCompany.com:443/dockerproxy')
      end
    end

    context 'Extracts the digest of an image' do
      let(:uri) { 'http://localhost:5000' }
      let(:registry) { DockerRegistry2::Registry.new(uri) }

      it 'Digest is extracted from a manifest with single arch' do
        VCR.use_cassette('manifest/ubuntu') do
          expect(connected_object.digest('my-image', '2.0')).to eq('sha256:1815c82652c03bfd8644afda26fb184f2ed891d921b20a0703b46768f9755c57')
        end
      end
      it 'Digest is extracted from a multiarch image' do
        VCR.use_cassette('manifest/multiarch_ubuntu') do
          expect(connected_object.digest('my-ubuntu', '17.04', 'amd64', 'linux')).to eq('sha256:213e05583a7cb8756a3f998e6dd65204ddb6b4c128e2175dcdf174cdf1877459')
        end

        VCR.use_cassette('manifest/multiarch_ubuntu') do
          expect(connected_object.digest('my-ubuntu', '17.04', 'arm64', 'linux')).to eq('sha256:213e05583a7cb8756a3f998e6dd65204ddb6b4c128e2175dcdf174cdf1877459')
        end
      end

      it 'Digest is extracted from a multiarch image with variant' do
        VCR.use_cassette('manifest/multiarch_php_variant') do
          expect(connected_object.digest('php', 'latest', 'arm', 'linux', 'v5')).to eq('sha256:1eb3215f71b6dcf1a1f9bec5fde07ae166ecf43de16e48ebdff3641ee54cac72')
        end
      end

      manifests = [
        {
          'mediaType' => 'application/vnd.docker.distribution.manifest.v2+json',
          'size' => 1357,
          'digest' => 'sha256:213e05583a7cb8756a3f998e6dd65204ddb6b4c128e2175dcdf174cdf1877459',
          'platform' => {
            'architecture' => 'amd64',
            'os' => 'linux'
          }
        },
        {
          'mediaType' => 'application/vnd.docker.distribution.manifest.v2+json',
          'size' => 1357,
          'digest' => 'sha256:213e05583a7cb8756a3f998e6dd65204ddb6b4c128e2175dcdf174cdf1877459',
          'platform' => {
            'architecture' => 'arm64',
            'os' => 'linux'
          }
        }
      ]

      it 'When it a multiarch image and no arch/os are specified it returns the manifests' do
        VCR.use_cassette('manifest/multiarch_ubuntu') do
          expect(connected_object.digest('my-ubuntu', '17.04')).to eq(manifests)
        end
      end

      it 'When it a multiarch image and only arch is given it returns the manifests' do
        VCR.use_cassette('manifest/multiarch_ubuntu') do
          expect(connected_object.digest('my-ubuntu', '17.04', 'arm64')).to eq(manifests)
        end
      end

      it 'When it a multiarch image and only os is given it returns the manifests' do
        VCR.use_cassette('manifest/multiarch_ubuntu') do
          expect(connected_object.digest('my-ubuntu', '17.04', nil, 'linux')).to eq(manifests)
        end
      end

      it 'Fails when there are no matches' do
        VCR.use_cassette('manifest/multiarch_ubuntu') do
          expect do
            connected_object.digest('my-ubuntu',
                                    '17.04', 'arm64', 'windows')
          end.to raise_error(DockerRegistry2::NotFound, 'No matches found for the image=my-ubuntu tag=17.04 os=windows architecture=arm64')
        end
      end
    end
  end
end
