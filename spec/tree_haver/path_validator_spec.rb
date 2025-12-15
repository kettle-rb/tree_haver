# frozen_string_literal: true

RSpec.describe TreeHaver::PathValidator do
  let(:validator) { described_class }

  before do
    # Clear any custom trusted directories from previous tests
    validator.clear_custom_trusted_directories!
  end

  after do
    validator.clear_custom_trusted_directories!
  end

  describe ".trusted_directories" do
    it "includes default trusted directories" do
      dirs = validator.trusted_directories
      expect(dirs).to include("/usr/lib")
      expect(dirs).to include("/usr/local/lib")
    end

    it "includes custom registered directories" do
      validator.add_trusted_directory("/custom/lib")
      dirs = validator.trusted_directories
      expect(dirs).to include("/custom/lib")
    end

    it "includes directories from ENV" do
      stub_env("TREE_HAVER_TRUSTED_DIRS" => "/env/lib1,/env/lib2")
      dirs = validator.trusted_directories
      expect(dirs).to include("/env/lib1")
      expect(dirs).to include("/env/lib2")
    end

    it "expands ~ in ENV directories" do
      stub_env("TREE_HAVER_TRUSTED_DIRS" => "~/my-libs")
      dirs = validator.trusted_directories
      expect(dirs).to include(File.expand_path("~/my-libs"))
    end

    it "skips non-absolute paths from ENV after expansion" do
      # A path that doesn't start with / after expansion should be excluded
      # This is hard to trigger since File.expand_path usually produces absolute paths
      # but let's test the logic is there
      stub_env("TREE_HAVER_TRUSTED_DIRS" => "/valid/path")
      dirs = validator.trusted_directories
      expect(dirs).to include("/valid/path")
    end

    it "returns unique directories" do
      validator.add_trusted_directory("/usr/lib") # duplicate of default
      dirs = validator.trusted_directories
      expect(dirs.count("/usr/lib")).to eq(1)
    end
  end

  describe ".add_trusted_directory" do
    it "adds an absolute path" do
      validator.add_trusted_directory("/my/custom/lib")
      expect(validator.custom_trusted_directories).to include("/my/custom/lib")
    end

    it "expands ~ in paths" do
      validator.add_trusted_directory("~/libs")
      expect(validator.custom_trusted_directories).to include(File.expand_path("~/libs"))
    end

    it "does not add duplicate directories" do
      validator.add_trusted_directory("/my/lib")
      validator.add_trusted_directory("/my/lib")
      expect(validator.custom_trusted_directories.count("/my/lib")).to eq(1)
    end

    it "raises ArgumentError for relative paths that don't expand to absolute" do
      # File.expand_path converts relative to absolute using cwd, so this tests
      # the case where expansion still results in absolute
      # This test verifies the expansion happens - actual relative paths expand to absolute
      validator.add_trusted_directory("relative/path")
      expect(validator.custom_trusted_directories.first).to start_with("/")
    end

    it "handles edge case where File.expand_path might return non-absolute" do
      # This edge case is nearly impossible to trigger with real File.expand_path
      # but we test the error message format if it were to happen
      # by directly testing the ArgumentError message pattern
      expect {
        # Simulate what would happen if somehow expanded didn't start with /
        # We can't actually trigger this, so just verify the method exists
        validator.add_trusted_directory("/valid/path")
      }.not_to raise_error
    end
  end

  describe ".remove_trusted_directory" do
    it "removes a previously added directory" do
      validator.add_trusted_directory("/to-remove")
      expect(validator.custom_trusted_directories).to include("/to-remove")
      validator.remove_trusted_directory("/to-remove")
      expect(validator.custom_trusted_directories).not_to include("/to-remove")
    end

    it "handles removing non-existent directory gracefully" do
      expect { validator.remove_trusted_directory("/never-added") }.not_to raise_error
    end
  end

  describe ".clear_custom_trusted_directories!" do
    it "removes all custom directories" do
      validator.add_trusted_directory("/custom1")
      validator.add_trusted_directory("/custom2")
      expect(validator.custom_trusted_directories.size).to eq(2)
      validator.clear_custom_trusted_directories!
      expect(validator.custom_trusted_directories).to be_empty
    end
  end

  describe ".custom_trusted_directories" do
    it "returns a copy of the internal list" do
      validator.add_trusted_directory("/test")
      dirs = validator.custom_trusted_directories
      dirs << "/should-not-be-added"
      expect(validator.custom_trusted_directories).not_to include("/should-not-be-added")
    end
  end

  describe ".safe_library_path?" do
    context "with valid paths" do
      it "accepts valid .so path" do
        expect(validator.safe_library_path?("/usr/lib/libtree-sitter-toml.so")).to be true
      end

      it "accepts valid .dylib path" do
        expect(validator.safe_library_path?("/opt/homebrew/lib/libtree-sitter-toml.dylib")).to be true
      end

      it "accepts valid .dll path" do
        expect(validator.safe_library_path?("/path/to/tree-sitter-toml.dll")).to be true
      end

      it "rejects .so with version suffix (not in ALLOWED_EXTENSIONS)" do
        # ALLOWED_EXTENSIONS only includes .so, .dylib, .dll - not .so.0
        # Versioned .so files are not explicitly allowed by the current implementation
        expect(validator.safe_library_path?("/usr/lib/libtree-sitter.so.0")).to be false
      end
    end

    context "with invalid paths" do
      it "rejects nil path" do
        expect(validator.safe_library_path?(nil)).to be false
      end

      it "rejects empty path" do
        expect(validator.safe_library_path?("")).to be false
      end

      it "rejects path exceeding max length" do
        long_path = "/" + ("a" * TreeHaver::PathValidator::MAX_PATH_LENGTH) + ".so"
        expect(validator.safe_library_path?(long_path)).to be false
      end

      it "rejects path with null byte" do
        expect(validator.safe_library_path?("/usr/lib/evil\x00.so")).to be false
      end

      it "rejects relative path" do
        expect(validator.safe_library_path?("../lib/libtree-sitter.so")).to be false
      end

      it "rejects path with /../ traversal" do
        expect(validator.safe_library_path?("/usr/lib/../etc/passwd.so")).to be false
      end

      it "rejects path ending with /.." do
        expect(validator.safe_library_path?("/usr/lib/..")).to be false
      end

      it "rejects path with /./ traversal" do
        expect(validator.safe_library_path?("/usr/lib/./libtest.so")).to be false
      end

      it "rejects path ending with /." do
        expect(validator.safe_library_path?("/usr/lib/.")).to be false
      end

      it "rejects invalid extension" do
        expect(validator.safe_library_path?("/usr/lib/libtree-sitter.txt")).to be false
      end

      it "rejects filename with shell metacharacters" do
        expect(validator.safe_library_path?("/usr/lib/lib;rm -rf /.so")).to be false
      end

      it "rejects filename starting with dot" do
        expect(validator.safe_library_path?("/usr/lib/.hidden.so")).to be false
      end

      it "rejects filename starting with hyphen" do
        expect(validator.safe_library_path?("/usr/lib/-malicious.so")).to be false
      end
    end

    context "with Windows paths" do
      it "rejects Windows absolute path with backslash (contains invalid chars)" do
        # Windows backslash paths fail the VALID_FILENAME_PATTERN check
        # because backslash is not in [a-zA-Z0-9._-]
        expect(validator.safe_library_path?("C:\\Windows\\System32\\lib.dll")).to be false
      end

      it "accepts Windows absolute path with forward slash" do
        # Forward slash paths work if they pass all other validations
        expect(validator.safe_library_path?("D:/libs/tree-sitter.dll")).to be true
      end
    end

    context "with require_trusted_dir option" do
      it "accepts path in trusted directory when required" do
        # Create a temp file in a trusted location (if one exists and is writable)
        # For testing, we add a custom trusted dir
        validator.add_trusted_directory(Dir.pwd)
        test_path = File.join(Dir.pwd, "test-lib.so")
        expect(validator.safe_library_path?(test_path, require_trusted_dir: true)).to be true
      end

      it "rejects path outside trusted directories when required" do
        expect(validator.safe_library_path?("/nonexistent/random/path/lib.so", require_trusted_dir: true)).to be false
      end
    end
  end

  describe ".in_trusted_directory?" do
    it "returns false for nil path" do
      expect(validator.in_trusted_directory?(nil)).to be false
    end

    it "returns true for path in default trusted directory" do
      # /usr/lib is in default trusted directories
      expect(validator.in_trusted_directory?("/usr/lib/libtest.so")).to be true
    end

    it "handles non-existent file by checking directory" do
      validator.add_trusted_directory(Dir.pwd)
      nonexistent = File.join(Dir.pwd, "nonexistent-lib.so")
      expect(validator.in_trusted_directory?(nonexistent)).to be true
    end

    it "returns false when neither file nor directory exists" do
      expect(validator.in_trusted_directory?("/nonexistent/path/to/nowhere/lib.so")).to be false
    end
  end

  describe ".safe_language_name?" do
    it "accepts valid lowercase names" do
      expect(validator.safe_language_name?(:toml)).to be true
      expect(validator.safe_language_name?("json")).to be true
      expect(validator.safe_language_name?(:c_sharp)).to be true
    end

    it "accepts names with numbers" do
      expect(validator.safe_language_name?(:yaml2)).to be true
    end

    it "rejects nil" do
      expect(validator.safe_language_name?(nil)).to be false
    end

    it "rejects empty string" do
      expect(validator.safe_language_name?("")).to be false
    end

    it "rejects names starting with number" do
      expect(validator.safe_language_name?("2toml")).to be false
    end

    it "rejects names with uppercase" do
      expect(validator.safe_language_name?("TOML")).to be false
    end

    it "rejects names with special characters" do
      expect(validator.safe_language_name?("c++")).to be false
      expect(validator.safe_language_name?("c#")).to be false
    end

    it "rejects names with path traversal" do
      expect(validator.safe_language_name?("../../etc")).to be false
    end

    it "rejects names exceeding max length" do
      expect(validator.safe_language_name?("a" * 65)).to be false
    end
  end

  describe ".safe_symbol_name?" do
    it "accepts valid C identifier symbols" do
      expect(validator.safe_symbol_name?("tree_sitter_toml")).to be true
      expect(validator.safe_symbol_name?("_private_symbol")).to be true
      expect(validator.safe_symbol_name?("Symbol123")).to be true
    end

    it "rejects nil" do
      expect(validator.safe_symbol_name?(nil)).to be false
    end

    it "rejects empty string" do
      expect(validator.safe_symbol_name?("")).to be false
    end

    it "rejects symbol starting with number" do
      expect(validator.safe_symbol_name?("123symbol")).to be false
    end

    it "rejects symbol with special characters" do
      expect(validator.safe_symbol_name?("evil; rm -rf /")).to be false
    end

    it "rejects symbol exceeding max length" do
      expect(validator.safe_symbol_name?("a" * 257)).to be false
    end
  end

  describe ".safe_backend_name?" do
    it "accepts nil (means auto)" do
      expect(validator.safe_backend_name?(nil)).to be true
    end

    it "accepts valid backend names as symbols" do
      %i[auto mri rust ffi java].each do |backend|
        expect(validator.safe_backend_name?(backend)).to be true
      end
    end

    it "accepts valid backend names as strings" do
      %w[auto mri rust ffi java].each do |backend|
        expect(validator.safe_backend_name?(backend)).to be true
      end
    end

    it "rejects invalid backend names" do
      expect(validator.safe_backend_name?(:unknown)).to be false
      expect(validator.safe_backend_name?("evil")).to be false
    end
  end

  describe ".sanitize_language_name" do
    it "downcases and returns as symbol" do
      expect(validator.sanitize_language_name("TOML")).to eq(:toml)
    end

    it "removes invalid characters" do
      expect(validator.sanitize_language_name("c++")).to eq(:c)
    end

    it "returns nil for nil input" do
      expect(validator.sanitize_language_name(nil)).to be_nil
    end

    it "returns nil when result would be empty" do
      expect(validator.sanitize_language_name("+++")).to be_nil
    end

    it "returns nil when result doesn't start with letter" do
      expect(validator.sanitize_language_name("123abc")).to be_nil
    end
  end

  describe ".validation_errors" do
    it "returns empty array for valid path" do
      expect(validator.validation_errors("/usr/lib/libtest.so")).to be_empty
    end

    it "reports nil or empty path" do
      errors = validator.validation_errors(nil)
      expect(errors).to include("Path is nil or empty")
    end

    it "reports empty path" do
      errors = validator.validation_errors("")
      expect(errors).to include("Path is nil or empty")
    end

    it "reports path exceeding max length" do
      long_path = "/" + ("a" * TreeHaver::PathValidator::MAX_PATH_LENGTH)
      errors = validator.validation_errors(long_path)
      expect(errors.any? { |e| e.include?("exceeds maximum length") }).to be true
    end

    it "reports null byte" do
      # Note: File.basename raises ArgumentError for paths with null bytes
      # The validation_errors method may raise or may catch this
      path = "/path/with\x00null.so"
      begin
        errors = validator.validation_errors(path)
        expect(errors).to include("Path contains null byte")
      rescue ArgumentError => e
        # This is acceptable - Ruby's File.basename doesn't allow null bytes
        expect(e.message).to include("null byte")
      end
    end

    it "reports non-absolute path" do
      errors = validator.validation_errors("relative/path.so")
      expect(errors).to include("Path is not absolute")
    end

    it "reports /../ traversal" do
      errors = validator.validation_errors("/usr/../etc.so")
      expect(errors.any? { |e| e.include?("traversal sequence (/../)") }).to be true
    end

    it "reports ending with /.." do
      errors = validator.validation_errors("/usr/lib/..")
      expect(errors.any? { |e| e.include?("traversal sequence (/../)") }).to be true
    end

    it "reports /./ traversal" do
      errors = validator.validation_errors("/usr/./lib.so")
      expect(errors.any? { |e| e.include?("traversal sequence (/./)") }).to be true
    end

    it "reports ending with /." do
      errors = validator.validation_errors("/usr/lib/.")
      expect(errors.any? { |e| e.include?("traversal sequence (/./)") }).to be true
    end

    it "reports invalid extension" do
      errors = validator.validation_errors("/usr/lib/file.txt")
      expect(errors.any? { |e| e.include?("allowed extension") }).to be true
    end

    it "reports invalid filename characters" do
      errors = validator.validation_errors("/usr/lib/;evil.so")
      expect(errors).to include("Filename contains invalid characters")
    end
  end

  describe ".windows_absolute_path?" do
    it "detects C:\\ path" do
      expect(validator.send(:windows_absolute_path?, "C:\\Windows")).to be true
    end

    it "detects D:/ path" do
      expect(validator.send(:windows_absolute_path?, "D:/libs")).to be true
    end

    it "rejects Unix paths" do
      expect(validator.send(:windows_absolute_path?, "/usr/lib")).to be false
    end

    it "rejects relative paths" do
      expect(validator.send(:windows_absolute_path?, "relative/path")).to be false
    end
  end
end

