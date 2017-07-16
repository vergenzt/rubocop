# frozen_string_literal: true

describe RuboCop::CommentDirective do
  let(:comment) { parse_source(source).comments.first }
  let(:source) { '' } # overridden in lower contexts

  let(:all_cops) do
    array_larger_than(200)
  end

  describe '.each_from_comment' do
    subject do
      directives = []
      described_class.each_from_comment(comment) do |directive|
        directives << directive
      end
      directives
    end

    def expect_directive(keyword, cop_names = nil, source = nil)
      directive = subject.pop
      expect(directive.keyword).to eq(keyword)
      expect(directive.cop_names).to match_array(cop_names) if cop_names
      expect(directive.source_range.source).to eq(source) if source
    end

    # Make sure we set up expectations for all directives in the source.
    after do
      expect(subject).to be_empty
    end

    context 'when comment is nil' do
      let(:comment) { nil }
      it { is_expected.to be_empty }
    end

    context 'when comment has no directive' do
      let(:source) { '# no directive to see here' }
      it { is_expected.to be_empty }
    end

    context 'when comment has an invalid directive keyword' do
      let(:source) { '# rubocop:blahblahblah Test/SomeCop' }
      it { is_expected.to be_empty }
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
          dir_source = '# rubocop:disable Test/SomeCop'
          expect_directive(:disable, ['Test/SomeCop'], dir_source)
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
          dir_source = '# rubocop:disable Test/SomeCop, Test/SomeOtherCop'
          expect_directive(:disable, cops, dir_source)
        end
      end

      context 'with disable all' do
        let(:source) { '# rubocop:disable all' }
        it 'has a directive' do
          expect_directive(:disable, all_cops, source)
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
        it 'has directives' do
          expect_directive(:disable, ['Test/SomeCop'],
                           '# rubocop:disable Test/SomeCop')
          expect_directive(:todo, ['Test/OtherCop'],
                           '# rubocop:todo Test/OtherCop')
        end
      end

      context 'disable followed by disable' do
        let(:source) do
          '# rubocop:disable Test/SomeCop # rubocop:disable Test/OtherCop'
        end
        it 'has one directive' do
          expect_directive(:disable, ['Test/SomeCop'],
                           '# rubocop:disable Test/SomeCop')
        end
      end

      context 'disable followed by enable' do
        let(:source) do
          '# rubocop:disable Test/SomeCop # rubocop:enable Test/OtherCop'
        end
        it 'has one directive' do
          expect_directive(:disable, ['Test/SomeCop'],
                           '# rubocop:disable Test/SomeCop')
        end
      end

      context 'todo followed by disable' do
        let(:source) do
          '# rubocop:todo Test/SomeCop # rubocop:disable Test/OtherCop'
        end
        it 'has directives' do
          expect_directive(:todo, ['Test/SomeCop'],
                           '# rubocop:disable Test/SomeCop')
          expect_directive(:disable, ['Test/SomeCop'],
                           '# rubocop:disable Test/OtherCop')
        end
      end
    end
  end
end
