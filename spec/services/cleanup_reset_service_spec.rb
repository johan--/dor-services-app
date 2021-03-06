# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CleanupResetService do
  before do
    @fixtures = fixtures = Pathname(File.dirname(__FILE__)).join('../fixtures')

    allow(Settings.cleanup).to receive_messages(
      local_workspace_root: fixtures.join('workspace').to_s,
      local_assembly_root: fixtures.join('assembly').to_s,
      local_export_home: fixtures.join('export').to_s
    )

    @workspace_root_pathname = Pathname(Settings.cleanup.local_workspace_root)
    @reset_workitems_pathname = @workspace_root_pathname.join('cc/111')
    @reset_workitems_pathname.rmtree if @reset_workitems_pathname.exist?

    @assembly_root_pathname = Pathname(Settings.cleanup.local_assembly_root)
    @assembly_root_pathname.rmtree if @assembly_root_pathname.exist?

    @export_pathname = Pathname(Settings.cleanup.local_export_home)
    @export_pathname.rmtree if @export_pathname.exist?
  end

  context 'cleanup_by_reset_druid' do
    before do
      @druid_id = 'cc111cm1111'
      @druid = "druid:#{@druid_id}"
      @base_bag_dir = "#{@export_pathname}/#{@druid_id}_v1"
      @base_tar_dir = "#{@export_pathname}/#{@druid_id}_v1.tar"
      allow(described_class).to receive(:get_druid_last_version).and_return(1)
      @base_workspace_druid_path = DruidTools::Druid.new(@druid, @workspace_root_pathname.to_s).pathname
      @base_assembly_druid_path  = DruidTools::Druid.new(@druid, @assembly_root_pathname.to_s).pathname
      @base_workspace_druid_dir  = @base_workspace_druid_path.to_s
      @base_assembly_druid_dir   = @base_assembly_druid_path.to_s
    end

    it 'removes the reset druid tree from dor workspace and assembly, and reset bag from export' do
      create_bag_dir(@druid_id + '_v1')
      create_bag_tar(@druid_id + '_v1')
      create_druid_dir(@druid_id, 1, @workspace_root_pathname.to_s)
      create_druid_dir(@druid_id, nil, @assembly_root_pathname.to_s)
      expect(File).to exist(@base_bag_dir)
      expect(File).to exist(@base_tar_dir)
      expect(File).to exist(@base_workspace_druid_dir + '_v1')
      expect(File).to exist(@base_assembly_druid_dir)
      described_class.cleanup_by_reset_druid(@druid)
      expect(File).not_to exist(@base_bag_dir)
      expect(File).not_to exist(@base_tar_dir)
      expect(File).not_to exist(@base_workspace_druid_dir + '_v1')
      expect(File).not_to exist(@base_assembly_druid_dir)
    end
    it 'removes the reset druid tree from dor workspace and reset bag from export only, there is no assembly ws' do
      create_bag_dir(@druid_id + '_v1')
      create_bag_tar(@druid_id + '_v1')
      create_druid_dir(@druid_id, 1, @workspace_root_pathname.to_s)
      expect(File).to exist(@base_bag_dir)
      expect(File).to exist(@base_tar_dir)
      expect(File).to exist(@base_workspace_druid_dir + '_v1')
      expect(File).not_to exist(@base_assembly_druid_dir)
      described_class.cleanup_by_reset_druid(@druid)
      expect(File).not_to exist(@base_bag_dir)
      expect(File).not_to exist(@base_tar_dir)
      expect(File).not_to exist(@base_workspace_druid_dir + '_v1')
      expect(File).not_to exist(@base_assembly_druid_dir)
    end
    it 'removes the reset druid tree from dor workspace and assembly however they are symlink' do
      create_druid_dir(@druid_id, nil, @assembly_root_pathname.to_s)
      FileUtils.mkdir_p @base_workspace_druid_path.parent
      FileUtils.ln_s(@base_assembly_druid_dir, @base_workspace_druid_dir + '_v1', force: true)
      expect(File).to exist(@base_workspace_druid_dir + '_v1')
      expect(File).to exist(@base_assembly_druid_dir)
      described_class.cleanup_by_reset_druid(@druid)
      expect(File).not_to exist(@base_workspace_druid_dir + '_v1')
      expect(File).not_to exist(@base_assembly_druid_dir)
    end
  end

  # cleanup_reset_workspace_content
  ## cc111ci1111 - 1 version
  ## cc111cj1111 - 1 opened and 1 versioned
  ## cz111cz1111 - 1 version with root ancestor
  ## cc111ck1111 - 1 version with immediate ancestor
  ### cc111ck1112 support the previous version
  context 'cleanup_reset_workspace_content' do
    it 'removes the reset directory in workspace' do
      druid_id = 'cc111ci1111'
      druid = "druid:#{druid_id}"
      create_druid_dir(druid_id, 1, @workspace_root_pathname.to_s)

      base_druid_dir = DruidTools::Druid.new(druid, @workspace_root_pathname.to_s).pathname.to_s
      last_version = 1
      expect(File).to exist(base_druid_dir + '_v1')
      described_class.cleanup_reset_workspace_content(druid, last_version, @workspace_root_pathname.to_s)
      expect(File).not_to exist(base_druid_dir + '_v1')
    end

    it 'removes the reset directory and keep the open version' do
      druid_id = 'cc111cj1111'
      druid = "druid:#{druid_id}"
      create_druid_dir(druid_id, 2, @workspace_root_pathname.to_s)
      create_druid_dir(druid_id, 3, @workspace_root_pathname.to_s)

      base_druid_dir = DruidTools::Druid.new(druid, @workspace_root_pathname.to_s).pathname.to_s

      last_version = 2
      expect(File).to exist(base_druid_dir + '_v2')
      expect(File).to exist(base_druid_dir + '_v3')
      described_class.cleanup_reset_workspace_content(druid, last_version, @workspace_root_pathname.to_s)
      expect(File).not_to exist(base_druid_dir + '_v2')
      expect(File).to exist(base_druid_dir + '_v3')
    end
    it 'removes 1 version with root ancestor' do
      druid_id = 'cz111cz1111'
      druid = "druid:#{druid_id}"
      create_druid_dir(druid_id, 1, @workspace_root_pathname.to_s)
      base_druid_dir = DruidTools::Druid.new(druid, @workspace_root_pathname.to_s).pathname.to_s

      last_version = 1
      expect(File).to exist(base_druid_dir + '_v1')
      described_class.cleanup_reset_workspace_content(druid, last_version, @workspace_root_pathname.to_s)
      expect(File).not_to exist(@workspace_root_pathname.join('cz'))
    end

    it 'removes 1 version with immediate ancestor' do
      druid_id1 = 'cc111ck1111'
      druid_1 = "druid:#{druid_id1}"
      create_druid_dir(druid_id1, 1, @workspace_root_pathname.to_s)
      base_druid_dir_1 = DruidTools::Druid.new(druid_1, @workspace_root_pathname.to_s).pathname.to_s

      druid_id2 = 'cc111ck1112'
      druid_2 = "druid:#{druid_id2}"
      create_druid_dir(druid_id2, nil, @workspace_root_pathname.to_s)
      base_druid_dir_2 = DruidTools::Druid.new(druid_2, @workspace_root_pathname.to_s).pathname.to_s

      last_version = 1
      expect(File).to exist(base_druid_dir_1 + '_v1')
      expect(File).to exist(base_druid_dir_2)
      described_class.cleanup_reset_workspace_content(druid_1, last_version, @workspace_root_pathname.to_s)
      expect(File).not_to exist(base_druid_dir_1 + '_v1')
      expect(File).to exist(base_druid_dir_2)
      expect(File).not_to exist(@workspace_root_pathname.join('cc').join('111').join('ck').join('1111'))
      expect(File).to exist(@workspace_root_pathname.join('cc').join('111').join('ck'))
    end
  end

  # workspace_dir_list
  ## cc111cf1111 - 1 version
  ## cc111cg1111 - 2 version (v2 and v3)
  ## cc111ch1111 - 1 version (v1) and 1 opened version (v2)

  context 'get_reset_dirctories_list' do
    before do
      @druid_1v = 'cc111cf1111'
      @druid_2v = 'cc111cg1111'
      @druid_1_1v = 'cc111ch1111'
      create_druid_dir(@druid_1v, 1, @workspace_root_pathname.to_s)
      create_druid_dir(@druid_2v, 2, @workspace_root_pathname.to_s)
      create_druid_dir(@druid_2v, 3, @workspace_root_pathname.to_s)
      create_druid_dir(@druid_1_1v, 1, @workspace_root_pathname.to_s)
      create_druid_dir(@druid_1_1v, 2, @workspace_root_pathname.to_s)
    end

    it 'gets one reset directory from workspace' do
      druid = "druid:#{@druid_1v}"
      base_druid_tree = DruidTools::Druid.new(druid, @workspace_root_pathname.to_s)
      last_version = 1
      dir_list = described_class.get_reset_dir_list(last_version, base_druid_tree.path)
      expect_dir_path = "#{base_druid_tree.path}_v1"
      expect(dir_list.length).to eq 1
      expect(dir_list[0]).to eq expect_dir_path
    end

    it 'gets two reset directories from workspace' do
      druid = "druid:#{@druid_2v}"
      base_druid_tree = DruidTools::Druid.new(druid, @workspace_root_pathname.to_s)
      last_version = 3
      dir_list = described_class.get_reset_dir_list(last_version, base_druid_tree.path)
      expect_dir_path_1 = "#{base_druid_tree.path}_v2"
      expect_dir_path_2 = "#{base_druid_tree.path}_v3"
      expect(dir_list.length).to eq 2
      expect(dir_list[0]).to eq expect_dir_path_1
      expect(dir_list[1]).to eq expect_dir_path_2
    end

    it 'gets one reset directory from workspace and avoid the open version' do
      druid = "druid:#{@druid_1_1v}"
      base_druid_tree = DruidTools::Druid.new(druid, @workspace_root_pathname.to_s)
      last_version = 1
      dir_list = described_class.get_reset_dir_list(last_version, base_druid_tree.path)
      expect_dir_path = "#{base_druid_tree.path}_v1"
      expect(dir_list.length).to eq 1
      expect(dir_list[0]).to eq expect_dir_path
    end
  end

  # export
  ## cc111cd1111 - 1 dir and 1 tar
  ## cc111ce1111 - 2 dir opened and versioned and 2 tar opened and reset
  ##
  context 'cleanup_reset_export' do
    before do
      @druid_1v = 'cc111cd1111'
      create_bag_dir(@druid_1v + '_v1')
      create_bag_tar(@druid_1v + '_v1')
    end

    it 'removes both bag tar and directory' do
      druid = "druid:#{@druid_1v}"
      base_bag_dir = "#{@export_pathname}/#{@druid_1v}_v1"
      expect(File).to exist(base_bag_dir)
      expect(File).to exist(base_bag_dir + '.tar')
      described_class.cleanup_reset_export(druid, 1)
      expect(File).not_to exist(base_bag_dir)
      expect(File).not_to exist(base_bag_dir + '.tar')
    end
  end

  context 'get_reset_bag_dir_list' do
    before do
      @druid_1v = 'cc111ca1111'
      @druid_2v = 'cc111cb1111'
      @druid_1_1v = 'cc111cc1111'
      create_bag_dir(@druid_1v + '_v1')
      create_bag_dir(@druid_2v + '_v2')
      create_bag_dir(@druid_2v + '_v3')
      create_bag_dir(@druid_1_1v + '_v1')
      create_bag_dir(@druid_1_1v)
    end

    it 'reads the bag directory with 1 version' do
      base_bag_dir = "#{@export_pathname}/#{@druid_1v}"
      dir_list = described_class.get_reset_bag_dir_list(1, base_bag_dir)
      expect_dir_file = "#{base_bag_dir}_v1"
      expect(dir_list.length).to eq 1
      expect(dir_list[0]).to eq expect_dir_file
    end

    it 'returns a list of bag directories with 2 versions' do
      base_bag_dir = "#{@export_pathname}/#{@druid_2v}"
      dir_list = described_class.get_reset_bag_dir_list(3, base_bag_dir)
      expect_dir_file_1 = "#{base_bag_dir}_v2"
      expect_dir_file_2 = "#{base_bag_dir}_v3"
      expect(dir_list.length).to eq 2
      expect(dir_list[0]).to eq expect_dir_file_1
      expect(dir_list[1]).to eq expect_dir_file_2
    end

    it 'returns a list of tars with 1 version and 1 opened version' do
      base_bag_dir = "#{@export_pathname}/#{@druid_1_1v}"
      dir_list = described_class.get_reset_bag_dir_list(1, base_bag_dir)
      expect_dir_file = "#{base_bag_dir}_v1"
      expect(dir_list.length).to eq 1
      expect(dir_list[0]).to eq expect_dir_file
    end
  end

  context 'get_reset_bag_tar_list' do
    before do
      @druid_1v = 'cc111ca1111'
      @druid_2v = 'cc111cb1111'
      @druid_1_1v = 'cc111cc1111'
      create_bag_dir(@druid_1v + '_v1')
      create_bag_dir(@druid_2v + '_v2')
      create_bag_dir(@druid_2v + '_v3')
      create_bag_dir(@druid_1_1v + '_v1')
      create_bag_dir(@druid_1_1v)

      create_bag_tar(@druid_1v + '_v1')
      create_bag_tar(@druid_2v + '_v2')
      create_bag_tar(@druid_2v + '_v3')
      create_bag_tar(@druid_1_1v + '_v1')
      create_bag_tar(@druid_1_1v)
    end

    it 'returns a list of tars with 1 version' do
      base_bag_dir = "#{@export_pathname}/#{@druid_1v}"
      tar_list = described_class.get_reset_bag_tar_list(1, base_bag_dir)
      expect_tar_file = "#{base_bag_dir}_v1.tar"
      expect(tar_list.length).to eq 1
      expect(tar_list[0]).to eq expect_tar_file
    end

    it 'returns a list of tars with 2 versions' do
      base_bag_dir = "#{@export_pathname}/#{@druid_2v}"
      tar_list = described_class.get_reset_bag_tar_list(3, base_bag_dir)
      expect_tar_file_1 = "#{base_bag_dir}_v2.tar"
      expect_tar_file_2 = "#{base_bag_dir}_v3.tar"
      expect(tar_list.length).to eq 2
      expect(tar_list[0]).to eq expect_tar_file_1
      expect(tar_list[1]).to eq expect_tar_file_2
    end

    it 'returns a list of tars with 1 version and 1 opened version' do
      base_bag_dir = "#{@export_pathname}/#{@druid_1_1v}"
      tar_list = described_class.get_reset_bag_tar_list(1, base_bag_dir)
      expect_tar_file = "#{base_bag_dir}_v1.tar"
      expect(tar_list.length).to eq 1
      expect(tar_list[0]).to eq expect_tar_file
    end
  end

  context 'cleanup_assembly_content' do
    it 'cleanups the assembly workspace' do
      druid_id = 'ab123cd4567'
      create_druid_dir(druid_id, nil, @assembly_root_pathname.to_s)
      expect(File).to exist(@assembly_root_pathname.join('ab').join('123').join('cd').join('4567'))
      described_class.cleanup_assembly_content(druid_id, @assembly_root_pathname.to_s)
      expect(File).not_to exist(@assembly_root_pathname.join('ab').join('123').join('cd').join('4567'))
    end
    it 'does not do anything if the assembly workspace is empty' do
      druid_id = 'ef123gh4567'
      expect(File).not_to exist(@assembly_root_pathname.join('ab').join('123').join('cd').join('4567'))
      expect { described_class.cleanup_assembly_content(druid_id, @assembly_root_pathname.to_s) }.not_to raise_error
      expect(File).not_to exist(@assembly_root_pathname.join('ab').join('123').join('cd').join('4567'))
    end
  end

  def create_bag_tar(file_name)
    tarfile_pathname = @export_pathname.join(file_name + '.tar')
    tarfile_pathname.open('w') { |file| file.write("test tar\n") }
  end

  def create_bag_dir(bag_name)
    bag_pathname = Pathname(@export_pathname.join(bag_name))
    bag_pathname.mkpath
    bag_pathname.join('content').mkpath
    bag_pathname.join('temp').mkpath
  end

  def create_druid_dir(druid_id, version, base_dir)
    druid = "druid:#{druid_id}"
    base_druid_tree = DruidTools::Druid.new(druid, base_dir)
    base_druid_dir = base_druid_tree.pathname.to_s
    if version.nil?
      Pathname(base_druid_dir.to_s).mkpath unless File.exist?(base_druid_dir.to_s)
    else
      Pathname("#{base_druid_dir}_v#{version}").mkpath unless File.exist?("#{base_druid_dir}_v#{version}")
    end
  end
end
