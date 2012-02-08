#pragma once

#include "../base/buffer_vector.hpp"

#include "../std/string.hpp"
#include "../std/stdint.hpp"
#include "../std/sstream.hpp"

#include "../3party/utfcpp/source/utf8/unchecked.h"

/// All methods work with strings in utf-8 format
namespace strings
{

typedef uint32_t UniChar;
//typedef buffer_vector<UniChar, 32> UniString;

/// Make new type, not typedef. Need to specialize DebugPrint.
class UniString : public buffer_vector<UniChar, 32>
{
  typedef buffer_vector<UniChar, 32> BaseT;
public:
  UniString() {}
  explicit UniString(size_t n, UniChar c = UniChar()) : BaseT(n, c) {}
  template <class IterT> UniString(IterT b, IterT e) : BaseT(b, e) {}
};

UniString MakeLowerCase(UniString const & s);
void MakeLowerCase(UniString & s);
UniString Normalize(UniString const & s);
void Normalize(UniString & s);

void MakeLowerCase(string & s);
string MakeLowerCase(string const & s);
bool EqualNoCase(string const & s1, string const & s2);

inline UniString MakeUniString(string const & utf8s)
{
  UniString result;
  utf8::unchecked::utf8to32(utf8s.begin(), utf8s.end(), back_inserter(result));
  return result;
}

inline string ToUtf8(UniString const & s)
{
  string result;
  utf8::unchecked::utf32to8(s.begin(), s.end(), back_inserter(result));
  return result;
}

inline string DebugPrint(UniString const & s)
{
  return ToUtf8(s);
}

template <typename DelimFuncT, typename UniCharIterT = UniString::const_iterator>
class TokenizeIterator
{
  UniCharIterT m_beg, m_end, m_finish;
  DelimFuncT m_delimFunc;

  /// Explicitly disabled, because we're storing iterators for string
  TokenizeIterator(char const *, DelimFuncT);

  void move()
  {
    m_beg = m_end;
    while (m_beg != m_finish)
    {
      if (m_delimFunc(*m_beg))
        ++m_beg;
      else
        break;
    }
    m_end = m_beg;
    while (m_end != m_finish)
    {
      if (m_delimFunc(*m_end))
        break;
      else
        ++m_end;
    }
  }

public:
  TokenizeIterator(string const & s, DelimFuncT delimFunc)
  : m_beg(s.begin()), m_end(s.begin()), m_finish(s.end()), m_delimFunc(delimFunc)
  {
    move();
  }

  TokenizeIterator(UniString const & s, DelimFuncT delimFunc)
  : m_beg(s.begin()), m_end(s.begin()), m_finish(s.end()), m_delimFunc(delimFunc)
  {
    move();
  }

  string operator*() const
  {
    ASSERT( m_beg != m_finish, ("dereferencing of empty iterator") );
    return string(m_beg.base(), m_end.base());
  }

  operator bool() const { return m_beg != m_finish; }

  TokenizeIterator & operator++()
  {
    move();
    return (*this);
  }

  bool IsLast() const
  {
    if (!*this)
      return false;
    TokenizeIterator<DelimFuncT, UniCharIterT> copy(*this);
    ++copy;
    return !copy;
  }

  UniString GetUniString() const
  {
    UniString result;
    UniCharIterT iter(m_beg);
    while (iter != m_end)
    {
      result.push_back(*iter);
      ++iter;
    }
    return result;
  }
};

class SimpleDelimiter
{
  UniString m_delims;
public:
  SimpleDelimiter(char const * delimChars);
  /// @return true if c is delimiter
  bool operator()(UniChar c) const;
};

typedef TokenizeIterator<SimpleDelimiter,
                         ::utf8::unchecked::iterator<string::const_iterator> > SimpleTokenizer;

template <typename FunctorT>
void Tokenize(string const & str, char const * delims, FunctorT f)
{
  SimpleTokenizer iter(str, delims);
  while (iter)
  {
    f(*iter);
    ++iter;
  }
}

/// @return code of last symbol in string or 0 if s is empty
UniChar LastUniChar(string const & s);

template <class T, size_t N, class TT> bool IsInArray(T (&arr) [N], TT const & t)
{
  for (size_t i = 0; i < N; ++i)
    if (arr[i] == t) return true;
  return false;
}

bool to_int(char const * s, int & i);
bool to_uint64(char const * s, uint64_t & i);
bool to_int64(char const * s, int64_t & i);
bool to_double(char const * s, double & d);

template <class T>
string to_string(T i)
{
  ostringstream ss;
  ss << i;
  return ss.str();
}

inline bool to_int(string const & s, int & i) { return to_int(s.c_str(), i); }
inline bool to_uint64(string const & s, uint64_t & i) { return to_uint64(s.c_str(), i); }
inline bool to_int64(string const & s, int64_t & i) { return to_int64(s.c_str(), i); }
inline bool to_double(string const & s, double & d) { return to_double(s.c_str(), d); }

template <typename ItT, typename DelimiterT>
typename ItT::value_type JoinStrings(ItT begin, ItT end, DelimiterT const & delimiter)
{
  typedef typename ItT::value_type StringT;

  if (begin == end) return StringT();

  StringT result = *begin++;
  for (ItT it = begin; it != end; ++it)
  {
    result += delimiter;
    result += *it;
  }

  return result;
}

template <typename ContainerT, typename DelimiterT>
typename ContainerT::value_type JoinStrings(ContainerT const & container,
                                            DelimiterT const & delimiter)
{
  return JoinStrings(container.begin(), container.end(), delimiter);
}

}
