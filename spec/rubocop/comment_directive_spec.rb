# frozen_string_literal: true

describe RuboCop::CommentDirective do
  let(:comment) { parse_source(source).comments.first }
  let(:source) { '' } # overridden in lower contexts

  describe '.from_comment' do
    subject { described_class.from_comment(comment) }

    def expect_directive(keyword, cop_names = nil, source = nil, desc = nil)
      expect(subject.keyword).to eq(keyword)
      expect(subject.cop_names).to match_array(cop_names) if cop_names.is_a? Array
      expect(subject.all_cops?).to be(true) if cop_names == :all_cops
      expect(subject.source_range.source).to eq(source) if source
      expect(subject.description).to eq(desc) if desc
    end

    context 'when comment is nil' do
      let(:comment) { nil }
      it { is_expected.to be_nil }
    end

    context 'when comment has no directive' do
      let(:source) { '# no directive to see here' }
      it { is_expected.to be_nil }
    end

    context 'when comment has an invalid directive keyword' do
      let(:source) { '# rubocop:blahblahblah Test/SomeCop' }
      it { is_expected.to be_nil }
    end

    context 'when a comment has a disable directive' do
      context 'with one cop' do
        let(:source) { '# rubocop:disable Test/SomeCop' }
        it 'has a directive' do
          expect_directive(:disable, ['Test/SomeCop'], source)
        end
      end

      context 'with one cop and a comment' do
        let(:source) { '# rubocop:disable Test/SomeCop with a comment' }
        it 'has a directive' do
          expect_directive(:disable, ['Test/SomeCop'], source, 'with a comment')
        end
      end

      context 'with two cops' do
        let(:source) { '# rubocop:disable Test/SomeCop, Test/SomeOtherCop' }
        it 'has a directive' do
          expect_directive(:disable, %w[Test/SomeCop Test/SomeOtherCop], source)
        end
      end

      context 'with two cops and a comment' do
        let(:source) do
          '# rubocop:disable Test/SomeCop, Test/SomeOtherCop plus comment'
        end
        it 'has a directive' do
          cops = %w[Test/SomeCop Test/SomeOtherCop]
          expect_directive(:disable, cops, source, 'plus comment')
        end
      end

      context 'with disable all' do
        let(:source) { '# rubocop:disable all' }
        it 'has a directive' do
          expect_directive(:disable, :all_cops, source)
        end
      end
    end

    context 'when a comment has an enable directive' do
      context 'with one cop' do
        let(:source) { '# rubocop:enable Test/SomeCop' }
        it 'has a directive' do
          expect_directive(:enable, ['Test/SomeCop'], source)
        end
      end
    end

    context 'when a comment has multiple directives' do
      context 'disable followed by todo' do
        let(:source) do
          '# rubocop:disable Test/SomeCop # rubocop:todo Test/OtherCop'
        end
        it 'has a disable directive' do
          expect_directive(:disable, ['Test/SomeCop'], source,
                           '# rubocop:todo Test/OtherCop')
        end
      end

      context 'disable followed by disable' do
        let(:source) do
          '# rubocop:disable Test/SomeCop # rubocop:disable Test/OtherCop'
        end
        it 'has a disable directive' do
          expect_directive(:disable, ['Test/SomeCop'], source,
                           '# rubocop:disable Test/OtherCop')
        end
      end

      context 'disable followed by enable' do
        let(:source) do
          '# rubocop:disable Test/SomeCop # rubocop:enable Test/OtherCop'
        end
        it 'has a disable directive' do
          expect_directive(:disable, ['Test/SomeCop'], source,
                           '# rubocop:enable Test/OtherCop')
        end
      end
    end
  end

  describe '.cop_range' do
    let(:directive) { described_class.from_comment(comment) }

    context 'when directive includes' do
      context 'one cop' do
        let(:source) { '# rubocop:disable Metrics/LineLength' }

        it 'correctly identifies the range for the cop' do
          expect(directive.cop_range('Metrics/LineLength').source)
            .to eq('Metrics/LineLength')
        end
      end

      context 'one abbreviated cop' do
        let(:source) { '# rubocop:disable LineLength' }

        it 'correctly identifies the range for the cop' do
          expect(directive.cop_range('Metrics/LineLength').source)
            .to eq('LineLength')
        end
      end

      context 'two abbreviated cops' do
        let(:source) { '# rubocop:disable LineLength, ClassLength' }

        it 'correctly identifies the range for the cops' do
          expect(directive.cop_range('Metrics/LineLength').source)
            .to eq('LineLength')
          expect(directive.cop_range('Metrics/ClassLength').source)
            .to eq('ClassLength')
        end
      end

      context 'all cops' do
        let(:source) { '# rubocop:disable all' }

        it 'returns nil for all cops' do
          expect(directive.cop_range('Metrics/LineLength')).to be_nil
          expect(directive.cop_range('Metrics/ClassLength')).to be_nil
        end
      end
    end
  end
end
