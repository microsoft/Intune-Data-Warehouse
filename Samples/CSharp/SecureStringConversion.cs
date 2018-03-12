namespace IntuneDataWarehouseSamples
{
    using System;
    using System.Security;

    public static class SecureStringConversion
    {
        public static SecureString ToSecureString(this string str)
        {
            if (str == null)
                throw new ArgumentNullException("String must not be null.");

            var secure = new SecureString();

            foreach (char c in str)
                secure.AppendChar(c);

            secure.MakeReadOnly();
            return secure;
        }
    }
}
