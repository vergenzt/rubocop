# frozen_string_literal: true

describe RuboCop::CLI, :isolated_environment do
  include_context 'cli spec behavior'

  let(:cli) { described_class.new }
  let(:cli_args) { %w[--format emacs] }
  subject { cli.run(cli_args) }

  describe '--disable-uncorrectable' do
    let(:cli_args) { super() + %w[--auto-correct --disable-uncorrectable] }

    it 'does not disable anything for cops that support autocorrect' do
      create_file('example.rb', 'puts 1==2')
      expect(subject).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(<<-END.strip_indent)
        #{abs('example.rb')}:1:7: C: [Corrected] Surrounding space missing for operator `==`.
      END
      expect(IO.read('example.rb')).to eq("puts 1 == 2\n")
    end

    it 'adds one-line disable statement for one-line offenses' do
      create_file('example.rb', <<-END.strip_indent)
        def is_example
          true
        end
      END
      expect(subject).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(<<-END.strip_indent)
        #{abs('example.rb')}:1:5: C: [Corrected] Rename `is_example` to `example?`.
      END
      expect(IO.read('example.rb')).to eq(<<-END.strip_indent)
        def is_example # rubocop:disable Style/PredicateName
          true
        end
      END
    end

    it 'adds before-and-after disable statement for multiline offenses' do
      create_file('.rubocop.yml', <<-END.strip_indent)
        Metrics/MethodLength:
          Max: 1
      END
      create_file('example.rb', <<-END.strip_indent)
        def example
          puts 'line 1'
          puts 'line 2'
        end
      END
      expect(subject).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(<<-END.strip_indent)
        #{abs('example.rb')}:1:1: C: [Corrected] Method has too many lines. [2/1]
      END
      expect(IO.read('example.rb')).to eq(<<-END.strip_indent)
        def example # rubocop:disable Metrics/MethodLength
          puts 'line 1'
          puts 'line 2'
        end
      END
    end

    context 'in special cases' do
      #let(:cli_args) { super() + ['-d'] }

      it 'does not correct a long line ending with newline inside string' do
        create_file('example.rb', <<-END.strip_indent)
          puts 'example with a line that is too long (really way too long) and that continues onto
                a new line'
        END
        expect(subject).to eq(1)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<-END.strip_indent)
          #{abs('example.rb')}:1:81: C: Line is too long. [88/80]
        END
        expect(IO.read('example.rb')).to eq(<<-END.strip_indent)
          puts 'example with a line that is too long (really way too long) and that continues onto
                a new line'
        END
      end
    end
  end
end
