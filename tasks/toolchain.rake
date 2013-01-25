# Build toolchain

require 'tmpdir'
require 'fileutils'

namespace :toolchain do

  autotools_versions = %w[ 2.13 2.59 2.62 2.69 ]
  autotools_versions.each do |version|
    label = "AUTOCONF_#{version.gsub(/\W/, '')}"
    raise "Woah, why am I bothering to build autoconf #{version}? There is no #{label} constant" unless Object.const_defined? label

    packages = [ package_dep('/opt/csw/bin/gm4'  => 'gm4', :distros => [:solaris]),
                 package_dep('/opt/csw/bin/gsed' => 'gsed', :distros => [:solaris])
               ]

    file Object.const_get(label) => packages do |task|
      Rake::Task['environment:path'].invoke
      Dir.mktmpdir "autoconf-#{version}_build" do |dir|
        Dir.chdir dir do
          fakes = %w[ makeinfo help2man ]
          begin
            unless version == "2.62"
              fakes.each do |name|
                fake = File.new("#{BUILD}/bin/#{name}", 'w')
                fake.chmod 0700
                fake.close
              end
            end

            show_file('config.log') do
              sh "#{DEPS}/autoconf-#{version}/configure --prefix=#{BUILD} --program-suffix=#{version}"
            end

            gmake
            gmake "install"
            record_manifest task.name
          ensure
            fakes.each do |name|
              FileUtils.rm_f "#{BUILD}/bin/#{name}"
            end
          end
        end
      end
    end
  end

  file AUTOMAKE => AUTOCONF_262 do |task|
    Rake::Task['environment:path'].invoke

    # Automake needs a ./bootstrap, and then needs to be cleaned up afterward.
    with_autoconf "2.62" do
      Dir.chdir AUTOMAKE_SOURCE do
        begin
          sh "./bootstrap"

          # Now automake can be built.
          Dir.mktmpdir "automake_build" do |build_dir|
            Dir.chdir build_dir do
              show_file('config.log') do
                sh "#{AUTOMAKE_SOURCE}/configure", "--prefix=#{BUILD}"
              end

              gmake
              gmake "install"
              record_manifest task.name
            end
          end # mktmpdir "automake_build"
        ensure
          if Dir.pwd != AUTOMAKE_SOURCE
            puts "WARNING: Failed to reset files: #{AUTOMAKE_SOURCE}"
          else
            puts "Resetting changes automake made to itself: #{AUTOMAKE_SOURCE}"
            sh "git", "checkout", "HEAD", "."
            FileUtils.rm_rf "autom4te.cache"
          end
        end
      end # chdir AUTOMAKE_SOURCE
    end # with_autoconf
  end

  file AUTOCONF_ARCHIVE => ["environment:path", AUTOMAKE, AUTOCONF_269] do |task|
    # Gnulib must be in the path to build this.
    with_path "#{DEPS}/gnulib" do
      with_autoconf "2.69" do
        git_work AUTOCONF_ARCHIVE_SOURCE do
          sh "./bootstrap.sh"

          show_file('config.log') do
            sh "./configure", "--prefix=#{BUILD}"
          end

          fakes = %w[ makeinfo help2man ] # Needed for `make` and `make install`
          begin
            fakes.each do |name|
              fake = File.new("#{BUILD}/bin/#{name}", 'w')
              fake.write "#!/bin/sh\n"
              fake.chmod 0700
              fake.close
            end

            gmake "maintainer-all"
            gmake
            gmake "install"
          ensure
            fakes.each do |name|
              FileUtils.rm_f "#{BUILD}/bin/#{name}"
            end
          end

          record_manifest task.name
          puts "Manifest: #{task.name.inspect}"
        end # git_work AUTOCONF_ARCHIVE_SOURCE
      end # with_autoconf "2.69"
    end # with_path "DEPS/gnulib"
  end

  task :clean do
    %w[ info share/emacs share/autoconf ].each do |dir|
      FileUtils.rm_rf "#{BUILD}/#{dir}"
    end

    autotools_versions.each do |ver|
      Dir.glob("#{BUILD}/bin/*#{ver}").each { |file| FileUtils.rm_f file }
    end
  end

end
