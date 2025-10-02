-- AccessiAI Database Schema

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS \
uuid-ossp\;

-- Users table (extends Supabase auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro')),
  scans_used INTEGER DEFAULT 0,
  scans_limit INTEGER DEFAULT 1,
  stripe_customer_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Scans table
CREATE TABLE public.scans (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  url TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  issues JSONB,
  report_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY \Users
can
view
own
profile\ ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY \Users
can
update
own
profile\ ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY \Users
can
insert
own
profile\ ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY \Users
can
view
own
scans\ ON public.scans FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY \Users
can
insert
own
scans\ ON public.scans FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY \Users
can
update
own
scans\ ON public.scans FOR UPDATE USING (auth.uid() = user_id);

-- Functions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS \$\$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
